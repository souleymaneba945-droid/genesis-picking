import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location_repository.dart';
import 'package:genesis_picking/features/warehouse_location/data/remote/brand_warehouse_location_remote_repository.dart';

/// Récupère, au démarrage, toutes les correspondances marque → emplacement
/// connues du serveur central et les intègre localement — même principe
/// que `UserPullSync` : c'est ce qui permet à un emplacement saisi par
/// l'administrateur sur SON appareil de devenir visible sur celui du
/// coursier.
///
/// Best-effort et jamais bloquant : un échec réseau ici ne doit jamais
/// empêcher l'application de démarrer.
class BrandWarehouseLocationPullSync {
  BrandWarehouseLocationPullSync(this._local, this._remote);

  final BrandWarehouseLocationRepository _local;
  final BrandWarehouseLocationRemoteRepository _remote;

  Future<void> pullAll() async {
    final List<BrandWarehouseLocationRemoteRecord> records;
    try {
      records = await _remote.pullAll();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Impossible de récupérer les emplacements entrepôt du serveur, '
        'poursuite avec ceux déjà connus localement',
        tag: 'BrandWarehouseLocationPullSync',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    var integres = 0;
    for (final record in records) {
      try {
        await _local.upsertFromRemote(
          id: record.id,
          marque: record.marque,
          emplacement: record.emplacement,
        );
        integres++;
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Emplacement "${record.marque}" non intégré localement — les '
          'autres continuent d\'être synchronisés',
          tag: 'BrandWarehouseLocationPullSync',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    AppLogger.event(
      '$integres/${records.length} emplacement(s) entrepôt synchronisé(s) '
      'depuis le serveur',
      tag: 'BrandWarehouseLocationPullSync',
    );
  }
}
