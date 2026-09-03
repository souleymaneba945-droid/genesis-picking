import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/features/auth/data/remote/user_remote_repository.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';

/// Récupère, au démarrage, tous les comptes connus du serveur central et
/// les intègre localement — c'est ce qui permet à un compte créé sur UN
/// appareil (PC de l'admin, par exemple) d'être utilisable pour se
/// connecter sur un autre (téléphone d'un préparateur), dès que ce
/// dernier a eu accès au réseau au moins une fois depuis la création.
///
/// Best-effort et jamais bloquant (voir [SplashScreen]) : un échec réseau
/// ici ne doit jamais empêcher l'application de démarrer — elle reste
/// utilisable avec les comptes déjà connus localement.
class UserPullSync {
  UserPullSync(this._local, this._remote);

  final UserRepository _local;
  final UserRemoteRepository _remote;

  Future<void> pullAll() async {
    final List<UserRemoteRecord> records;
    try {
      records = await _remote.pullAll();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Impossible de récupérer les comptes du serveur, poursuite avec '
        'les comptes locaux déjà connus',
        tag: 'UserPullSync',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    // Chaque compte est intégré isolément : un souci sur UN compte (ex.
    // doublon local imprévu) ne doit jamais empêcher les autres d'être
    // récupérés — avant, une seule erreur au milieu de la boucle
    // interrompait la synchronisation de tous les comptes suivants.
    var integres = 0;
    for (final record in records) {
      try {
        await _local.upsertFromRemote(
          id: record.id,
          identifiant: record.identifiant,
          nomAffichage: record.nomAffichage,
          role: record.role,
          actif: record.actif,
          motDePasseHash: record.motDePasseHash,
          motDePasseSel: record.motDePasseSel,
          creeLe: record.creeLe,
        );
        integres++;
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Compte "${record.identifiant}" non intégré localement — les '
          'autres comptes continuent d\'être synchronisés',
          tag: 'UserPullSync',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    AppLogger.event(
      '$integres/${records.length} compte(s) synchronisé(s) depuis le '
      'serveur',
      tag: 'UserPullSync',
    );
  }
}
