import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/sync/firestore/firestore_providers.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location_pull_sync.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location_repository.dart';
import 'package:genesis_picking/features/warehouse_location/data/drift_brand_warehouse_location_repository.dart';
import 'package:genesis_picking/features/warehouse_location/data/remote/brand_warehouse_location_remote_repository.dart';
import 'package:genesis_picking/features/warehouse_location/data/remote/firestore_brand_warehouse_location_remote_repository.dart';
import 'package:genesis_picking/features/warehouse_location/data/syncing_brand_warehouse_location_repository.dart';
import 'package:genesis_picking/features/warehouse_location/domain/warehouse_location_service.dart';

/// Point d'échange des correspondances marque → emplacement avec le
/// serveur central — voir `MODULE_5_V2.md`, Rubrique 2.
final brandWarehouseLocationRemoteRepositoryProvider =
    Provider<BrandWarehouseLocationRemoteRepository>((ref) {
  return FirestoreBrandWarehouseLocationRemoteRepository(
    ref.watch(firestoreProvider),
  );
});

/// Dépôt des correspondances marque → emplacement — implémentation Drift
/// enveloppée par [SyncingBrandWarehouseLocationRepository] pour que
/// chaque écriture soit aussi transmise au serveur central, même principe
/// que `userRepositoryProvider`.
final brandWarehouseLocationRepositoryProvider =
    Provider<BrandWarehouseLocationRepository>((ref) {
  return SyncingBrandWarehouseLocationRepository(
    DriftBrandWarehouseLocationRepository(ref.watch(localDatabaseProvider)),
    ref.watch(brandWarehouseLocationRemoteRepositoryProvider),
  );
});

final warehouseLocationServiceProvider = Provider<WarehouseLocationService>((ref) {
  return WarehouseLocationService(ref.watch(brandWarehouseLocationRepositoryProvider));
});

/// Récupère, au démarrage, tous les emplacements connus du serveur — voir
/// `SplashScreen`, même principe que `userPullSyncProvider`.
final brandWarehouseLocationPullSyncProvider =
    Provider<BrandWarehouseLocationPullSync>((ref) {
  return BrandWarehouseLocationPullSync(
    ref.watch(brandWarehouseLocationRepositoryProvider),
    ref.watch(brandWarehouseLocationRemoteRepositoryProvider),
  );
});
