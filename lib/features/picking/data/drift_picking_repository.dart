import 'package:drift/drift.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/picking_repository.dart';
import 'package:genesis_picking/features/picking/data/product_repository.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Implémentation Drift de [PickingRepository].
///
/// Utilise directement [LocalDatabase] (plutôt que de composer les
/// interfaces abstraites `ProductRepository`/`TourRepository`) pour la
/// seule opération qui l'exige : [applyValidation], où la mise à jour de
/// l'état du produit ET du compteur de progression de la tournée doivent
/// réussir ou échouer ensemble, dans une unique transaction Drift.
class DriftPickingRepository implements PickingRepository {
  DriftPickingRepository(this._database, this._productRepository);

  final LocalDatabase _database;
  final ProductRepository _productRepository;

  @override
  Future<List<PickingProduct>> loadProducts(String tourId) async {
    await _productRepository.ensureStatusesInitialized(tourId);
    return _productRepository.listForTour(tourId);
  }

  @override
  Future<void> applyValidation({
    required String tourId,
    required String productLineId,
    required ProductState etat,
    int? quantiteCollectee,
  }) async {
    await _database.transaction(() async {
      await _database
          .into(_database.pickingProductStatusesTable)
          .insertOnConflictUpdate(
            PickingProductStatusesTableCompanion.insert(
              productLineId: productLineId,
              etat: etat,
              quantiteCollectee: Value(quantiteCollectee),
              miseAJourLe: Value(DateTime.now()),
            ),
          );

      final lines = await (_database.select(
        _database.tourProductLinesTable,
      )..where((tbl) => tbl.tourId.equals(tourId)))
          .get();
      final lineIds = lines.map((line) => line.id).toList();

      final statuses = await (_database.select(
        _database.pickingProductStatusesTable,
      )..where((tbl) => tbl.productLineId.isIn(lineIds)))
          .get();

      final produitsTraites =
          statuses.where((status) => status.etat.estTraite).length;

      await (_database.update(
        _database.toursTable,
      )..where((tbl) => tbl.id.equals(tourId)))
          .write(
        ToursTableCompanion(produitsTraites: Value(produitsTraites)),
      );
    });

    AppLogger.event(
      'Validation appliquée pour $productLineId (tournée $tourId) → $etat',
      tag: 'PickingRepository',
    );
  }
}
