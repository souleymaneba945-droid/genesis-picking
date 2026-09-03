import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/remote/user_remote_repository.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';

/// Décorateur de [UserRepository] : délègue tout à un dépôt local (Drift
/// en pratique) et transmet en plus, best-effort, chaque écriture réussie
/// (création, activation/désactivation, réinitialisation) vers le
/// serveur central — pour qu'un compte créé sur UN appareil devienne
/// utilisable, tôt ou tard, sur tous les autres appareils du même compte.
///
/// Aucune méthode de lecture ([findByIdentifiant], [credentialsFor],
/// [listAll], [isEmpty]) n'est modifiée : la connexion reste 100% locale
/// et fonctionne hors-ligne exactement comme avant — seule la
/// PROPAGATION entre appareils dépend du réseau, jamais la connexion
/// elle-même. Même principe que `TourRemoteSink` côté tournées.
class SyncingUserRepository implements UserRepository {
  SyncingUserRepository(this._local, this._remote);

  final UserRepository _local;
  final UserRemoteRepository _remote;

  @override
  Future<UserAccount?> findByIdentifiant(String identifiant) {
    return _local.findByIdentifiant(identifiant);
  }

  @override
  Future<({String hash, String sel})?> credentialsFor(String identifiant) {
    return _local.credentialsFor(identifiant);
  }

  @override
  Future<List<UserAccount>> listAll() => _local.listAll();

  @override
  Future<bool> isEmpty() => _local.isEmpty();

  @override
  Future<Result<UserAccount>> create({
    required String identifiant,
    required String nomAffichage,
    required UserRole role,
    required String motDePasse,
  }) async {
    final result = await _local.create(
      identifiant: identifiant,
      nomAffichage: nomAffichage,
      role: role,
      motDePasse: motDePasse,
    );
    await result.when(
      success: (account) => _pushAfterWrite(account.id),
      failure: (_) async {},
    );
    return result;
  }

  @override
  Future<Result<void>> setActive({
    required String userId,
    required bool actif,
  }) async {
    final result = await _local.setActive(userId: userId, actif: actif);
    await result.when(
      success: (_) => _pushAfterWrite(userId),
      failure: (_) async {},
    );
    return result;
  }

  @override
  Future<Result<void>> resetPassword({
    required String userId,
    required String nouveauMotDePasse,
  }) async {
    final result = await _local.resetPassword(
      userId: userId,
      nouveauMotDePasse: nouveauMotDePasse,
    );
    await result.when(
      success: (_) => _pushAfterWrite(userId),
      failure: (_) async {},
    );
    return result;
  }

  @override
  Future<void> upsertFromRemote({
    required String id,
    required String identifiant,
    required String nomAffichage,
    required UserRole role,
    required bool actif,
    required String motDePasseHash,
    required String motDePasseSel,
    required DateTime creeLe,
  }) {
    // Le sens inverse (un compte REÇU du serveur) ne doit jamais être
    // renvoyé au serveur : ce serait un aller-retour inutile, jamais un
    // vrai changement à propager.
    return _local.upsertFromRemote(
      id: id,
      identifiant: identifiant,
      nomAffichage: nomAffichage,
      role: role,
      actif: actif,
      motDePasseHash: motDePasseHash,
      motDePasseSel: motDePasseSel,
      creeLe: creeLe,
    );
  }

  /// Relit le compte tout juste écrit localement (pour obtenir le hash et
  /// le sel, jamais transmis au-delà de la couche d'authentification —
  /// voir `credentialsFor`) puis le transmet au serveur. Best-effort :
  /// une écriture locale réussie ne doit jamais être remise en cause par
  /// un échec réseau ensuite (principe Offline First, même logique que
  /// `ImportEngine`/`FirestoreTourRemoteSink`).
  Future<void> _pushAfterWrite(String userId) async {
    try {
      final account = await _findById(userId);
      final credentials = await _local.credentialsFor(account.identifiant);
      if (credentials == null) return;

      await _remote.push(
        UserRemoteRecord(
          id: account.id,
          identifiant: account.identifiant,
          nomAffichage: account.nomAffichage,
          role: account.role,
          actif: account.actif,
          motDePasseHash: credentials.hash,
          motDePasseSel: credentials.sel,
          creeLe: account.creeLe,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Compte modifié localement mais pas encore transmis au serveur : '
        '$userId',
        tag: 'SyncingUserRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<UserAccount> _findById(String userId) async {
    // `UserRepository` n'expose de recherche que par identifiant, jamais
    // par id — seule la liste complète permet de retrouver le compte
    // tout juste écrit (table de petite taille : quelques dizaines de
    // comptes au plus, ce parcours reste négligeable).
    final all = await _local.listAll();
    return all.firstWhere((a) => a.id == userId);
  }
}
