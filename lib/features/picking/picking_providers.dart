import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/features/picking/data/drift_picking_repository.dart';
import 'package:genesis_picking/features/picking/data/drift_product_repository.dart';
import 'package:genesis_picking/features/picking/data/picking_repository.dart';
import 'package:genesis_picking/features/picking/data/product_repository.dart';
import 'package:genesis_picking/features/picking/domain/picking_service.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return DriftProductRepository(ref.watch(localDatabaseProvider));
});

final pickingRepositoryProvider = Provider<PickingRepository>((ref) {
  return DriftPickingRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(productRepositoryProvider),
  );
});

final pickingServiceProvider = Provider<PickingService>((ref) {
  return PickingService(
    pickingRepository: ref.watch(pickingRepositoryProvider),
    tourRepository: ref.watch(tourRepositoryProvider),
    tourService: ref.watch(tourServiceProvider),
    activityLogSink: ref.watch(activityLogRepositoryProvider),
  );
});
