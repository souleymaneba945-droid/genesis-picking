import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location_repository.dart';
import 'package:genesis_picking/features/warehouse_location/data/remote/brand_warehouse_location_remote_repository.dart';

/// Décorateur de [BrandWarehouseLocationRepository] : délègue tout à un
/// dépôt local (Drift en pratique) et transmet en plus, best-effort,
/// chaque écriture réussie (création, modification, suppression) vers le
/// serveur central — même principe que `SyncingUserRepository`.
///
/// Aucune méthode de lecture ([listAll]) n'est modifiée : la liste reste
/// utilisable hors-ligne exactement comme avant — seule la PROPAGATION
/// entre appareils dépend du réseau.
class SyncingBrandWarehouseLocationRepository
    implements BrandWarehouseLocationRepository {
  SyncingBrandWarehouseLocationRepository(this._local, this._remote);

  final BrandWarehouseLocationRepository _local;
  final BrandWarehouseLocationRemoteRepository _remote;

  @override
  Future<List<BrandWarehouseLocation>> listAll() => _local.listAll();

  @override
  Future<Result<BrandWarehouseLocation>> create({
    required String marque,
    required String emplacement,
  }) async {
    final result = await _local.create(marque: marque, emplacement: emplacement);
    await result.when(
      success: (location) => _pushAfterWrite(location.id),
      failure: (_) async {},
    );
    return result;
  }

  @override
  Future<Result<void>> update({
    required String id,
    required String marque,
    required String emplacement,
  }) async {
    final result = await _local.update(
      id: id,
      marque: marque,
      emplacement: emplacement,
    );
    await result.when(
      success: (_) => _pushAfterWrite(id),
      failure: (_) async {},
    );
    return result;
  }

  @override
  Future<Result<void>> delete(String id) async {
    final result = await _local.delete(id);
    await result.when(
      success: (_) => _deleteRemoteBestEffort(id),
      failure: (_) async {},
    );
    return result;
  }

  @override
  Future<void> upsertFromRemote({
    required String id,
    required String marque,
    required String emplacement,
  }) {
    // Le sens inverse (reçu du serveur) ne doit jamais être renvoyé au
    // serveur — aller-retour inutile.
    return _local.upsertFromRemote(id: id, marque: marque, emplacement: emplacement);
  }

  Future<void> _pushAfterWrite(String id) async {
    try {
      final all = await _local.listAll();
      final location = all.firstWhere((l) => l.id == id);
      await _remote.push(
        BrandWarehouseLocationRemoteRecord(
          id: location.id,
          marque: location.marque,
          emplacement: location.emplacement,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Emplacement entrepôt modifié localement mais pas encore transmis '
        'au serveur : $id',
        tag: 'SyncingBrandWarehouseLocationRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _deleteRemoteBestEffort(String id) async {
    try {
      await _remote.deleteRemote(id);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Suppression non encore transmise au serveur : $id',
        tag: 'SyncingBrandWarehouseLocationRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
