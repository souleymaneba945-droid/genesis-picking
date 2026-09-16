import 'package:drift/drift.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location_repository.dart';
import 'package:uuid/uuid.dart';

/// Implémentation Drift de [BrandWarehouseLocationRepository].
class DriftBrandWarehouseLocationRepository
    implements BrandWarehouseLocationRepository {
  DriftBrandWarehouseLocationRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  @override
  Future<List<BrandWarehouseLocation>> listAll() async {
    final rows =
        await _database.select(_database.brandWarehouseLocationsTable).get();
    return rows.map(_toModel).toList();
  }

  /// `null` si aucune marque existante ne correspond à [marque] (comparaison
  /// insensible à la casse) — jamais une comparaison SQL brute (le champ
  /// n'a pas de contrainte d'unicité insensible à la casse en base).
  Future<BrandWarehouseLocation?> _findByMarque(String marque) async {
    final normalisee = marque.toLowerCase();
    final rows = await listAll();
    for (final row in rows) {
      if (row.marque.toLowerCase() == normalisee) return row;
    }
    return null;
  }

  @override
  Future<Result<BrandWarehouseLocation>> create({
    required String marque,
    required String emplacement,
  }) async {
    final existing = await _findByMarque(marque);
    if (existing != null) {
      return const Result.failure(
        ValidationException('Cette marque a déjà un emplacement.'),
      );
    }

    final id = _uuid.v4();
    await _database.into(_database.brandWarehouseLocationsTable).insert(
          BrandWarehouseLocationsTableCompanion.insert(
            id: id,
            marque: marque,
            emplacement: emplacement,
          ),
        );

    AppLogger.event(
      'Emplacement entrepôt créé : $marque → $emplacement',
      tag: 'BrandWarehouseLocationRepository',
    );

    return Result.success(
      BrandWarehouseLocation(id: id, marque: marque, emplacement: emplacement),
    );
  }

  @override
  Future<Result<void>> update({
    required String id,
    required String marque,
    required String emplacement,
  }) async {
    final existing = await _findByMarque(marque);
    if (existing != null && existing.id != id) {
      return const Result.failure(
        ValidationException('Cette marque a déjà un emplacement.'),
      );
    }

    final updated = await (_database.update(
      _database.brandWarehouseLocationsTable,
    )..where((tbl) => tbl.id.equals(id)))
        .write(
      BrandWarehouseLocationsTableCompanion(
        marque: Value(marque),
        emplacement: Value(emplacement),
      ),
    );

    if (updated == 0) {
      return const Result.failure(ValidationException('Emplacement introuvable.'));
    }

    AppLogger.event(
      'Emplacement entrepôt modifié : $id',
      tag: 'BrandWarehouseLocationRepository',
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    final deleted = await (_database.delete(
      _database.brandWarehouseLocationsTable,
    )..where((tbl) => tbl.id.equals(id)))
        .go();

    if (deleted == 0) {
      return const Result.failure(ValidationException('Emplacement introuvable.'));
    }

    AppLogger.event(
      'Emplacement entrepôt supprimé : $id',
      tag: 'BrandWarehouseLocationRepository',
    );
    return const Result.success(null);
  }

  @override
  Future<void> upsertFromRemote({
    required String id,
    required String marque,
    required String emplacement,
  }) async {
    // Même précaution que `DriftUserRepository.upsertFromRemote` : si CET
    // appareil possède déjà, localement, une entrée pour la même marque
    // mais un id DIFFÉRENT (créée localement avant que cette entrée du
    // serveur ne soit connue), l'insertion ci-dessous laisserait deux
    // lignes pour la même marque — le serveur central fait foi, l'entrée
    // locale en doublon est effacée avant d'accueillir la version du
    // serveur sous son propre id.
    final doublonLocal = await _findByMarque(marque);
    if (doublonLocal != null && doublonLocal.id != id) {
      AppLogger.warning(
        'Emplacement local en doublon pour "$marque" (id local '
        '${doublonLocal.id} ≠ id serveur $id) — remplacé par la version '
        'du serveur',
        tag: 'DriftBrandWarehouseLocationRepository',
      );
      await (_database.delete(
        _database.brandWarehouseLocationsTable,
      )..where((tbl) => tbl.id.equals(doublonLocal.id)))
          .go();
    }

    await _database.into(_database.brandWarehouseLocationsTable).insertOnConflictUpdate(
          BrandWarehouseLocationsTableCompanion.insert(
            id: id,
            marque: marque,
            emplacement: emplacement,
          ),
        );
  }

  BrandWarehouseLocation _toModel(BrandWarehouseLocationsTableData row) {
    return BrandWarehouseLocation(
      id: row.id,
      marque: row.marque,
      emplacement: row.emplacement,
    );
  }
}
