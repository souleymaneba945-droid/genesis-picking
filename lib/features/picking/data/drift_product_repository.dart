import 'package:drift/drift.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_repository.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Implémentation Drift de [ProductRepository].
///
/// Joint `TourProductLinesTable` (données brutes, Module 3) et
/// `PickingProductStatusesTable` (état de collecte, ce module) sans
/// jamais modifier la première.
class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._database);

  final LocalDatabase _database;

  @override
  Future<void> ensureStatusesInitialized(String tourId) async {
    final lines = await (_database.select(
      _database.tourProductLinesTable,
    )..where((tbl) => tbl.tourId.equals(tourId)))
        .get();
    if (lines.isEmpty) return;

    final lineIds = lines.map((line) => line.id).toList();
    final existingStatuses = await (_database.select(
      _database.pickingProductStatusesTable,
    )..where((tbl) => tbl.productLineId.isIn(lineIds)))
        .get();
    final existingIds = existingStatuses.map((s) => s.productLineId).toSet();

    final missing = lines.where((line) => !existingIds.contains(line.id));
    if (missing.isEmpty) return;

    await _database.batch((batch) {
      batch.insertAll(
        _database.pickingProductStatusesTable,
        [
          for (final line in missing)
            PickingProductStatusesTableCompanion.insert(
              productLineId: line.id,
              etat: ProductState.aRecuperer,
            ),
        ],
      );
    });
  }

  @override
  Future<List<PickingProduct>> listForTour(String tourId) async {
    final lines = await (_database.select(_database.tourProductLinesTable)
          ..where((tbl) => tbl.tourId.equals(tourId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.ordre)]))
        .get();
    if (lines.isEmpty) return const [];

    // Module 9 (audit performance) : une seule requête groupée pour tous
    // les statuts, au lieu d'une requête par ligne produit (N+1) — sans
    // changement de comportement, seulement de la vitesse d'exécution.
    final lineIds = lines.map((line) => line.id).toList();
    final statuses = await (_database.select(
      _database.pickingProductStatusesTable,
    )..where((tbl) => tbl.productLineId.isIn(lineIds)))
        .get();
    final statusByLineId = {
      for (final status in statuses) status.productLineId: status,
    };

    return [
      for (final line in lines)
        PickingProduct(
          id: line.id,
          tourId: line.tourId,
          ordre: line.ordre,
          nom: line.nom,
          description: line.description,
          imageUrl: line.imageUrl,
          quantiteDemandee: line.quantiteDemandee,
          emplacement: line.emplacement,
          etat: statusByLineId[line.id]?.etat ?? ProductState.aRecuperer,
          quantiteCollectee: statusByLineId[line.id]?.quantiteCollectee,
        ),
    ];
  }

  @override
  Future<PickingProduct?> findById(String productLineId) async {
    final line = await (_database.select(
      _database.tourProductLinesTable,
    )..where((tbl) => tbl.id.equals(productLineId)))
        .getSingleOrNull();
    if (line == null) return null;

    final status = await (_database.select(
      _database.pickingProductStatusesTable,
    )..where((tbl) => tbl.productLineId.equals(productLineId)))
        .getSingleOrNull();

    return PickingProduct(
      id: line.id,
      tourId: line.tourId,
      ordre: line.ordre,
      nom: line.nom,
      description: line.description,
      imageUrl: line.imageUrl,
      quantiteDemandee: line.quantiteDemandee,
      emplacement: line.emplacement,
      etat: status?.etat ?? ProductState.aRecuperer,
      quantiteCollectee: status?.quantiteCollectee,
    );
  }

  @override
  Future<void> updateState({
    required String productLineId,
    required ProductState etat,
    int? quantiteCollectee,
  }) async {
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
    AppLogger.event(
      'Produit $productLineId → état $etat'
      '${quantiteCollectee != null ? ' (quantité: $quantiteCollectee)' : ''}',
      tag: 'ProductRepository',
    );
  }
}
