import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';

/// Contrat abstrait d'accès aux comptes utilisateurs.
///
/// [AuthService] et les écrans de gestion des utilisateurs ne dépendent
/// que de cette interface, jamais directement de Drift — même principe
/// que [LocalStorageService] posé au Module 1. Permet de fournir une
/// implémentation en mémoire dans les tests (voir `test/features/auth/`).
abstract interface class UserRepository {
  /// Retourne le compte correspondant à cet identifiant de connexion, ou
  /// `null` s'il n'existe pas.
  Future<UserAccount?> findByIdentifiant(String identifiant);

  /// Nécessaire à [AuthService] pour vérifier le mot de passe : renvoie
  /// le hash et le sel associés à l'identifiant, séparément du modèle
  /// public [UserAccount] pour ne jamais faire transiter ces informations
  /// au-delà de la couche d'authentification.
  Future<({String hash, String sel})?> credentialsFor(String identifiant);

  Future<List<UserAccount>> listAll();

  Future<Result<UserAccount>> create({
    required String identifiant,
    required String nomAffichage,
    required UserRole role,
    required String motDePasse,
  });

  Future<Result<void>> setActive({required String userId, required bool actif});

  Future<Result<void>> resetPassword({
    required String userId,
    required String nouveauMotDePasse,
  });

  /// Vrai si aucun compte n'existe encore (permet à [DatabaseSeeder] de
  /// savoir s'il doit créer le compte administrateur initial).
  Future<bool> isEmpty();

  /// Insère ou met à jour un compte déjà connu ailleurs (reçu du serveur
  /// central) — [motDePasseHash]/[motDePasseSel] sont déjà calculés,
  /// jamais un mot de passe en clair. Additif, réservé à la
  /// synchronisation (voir `SyncingUserRepository`) : ni [create] ni les
  /// écrans de gestion des comptes ne l'utilisent.
  Future<void> upsertFromRemote({
    required String id,
    required String identifiant,
    required String nomAffichage,
    required UserRole role,
    required bool actif,
    required String motDePasseHash,
    required String motDePasseSel,
    required DateTime creeLe,
  });
}
