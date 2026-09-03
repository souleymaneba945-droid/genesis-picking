import 'package:drift/drift.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_repository.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:uuid/uuid.dart';

/// Implémentation Drift de [CourierRepository].
class DriftCourierRepository implements CourierRepository {
  DriftCourierRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  @override
  Future<CourierRequest> create({
    required String preparateurId,
    required String coursierId,
    required String tourId,
    required String productLineId,
    required int quantiteDemandee,
    required String emplacement,
    String? produitNom,
    String? produitDescription,
    String? produitImageUrl,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _database.into(_database.courierRequestsTable).insert(
          CourierRequestsTableCompanion.insert(
            id: id,
            preparateurId: preparateurId,
            coursierId: coursierId,
            tourId: tourId,
            productLineId: productLineId,
            quantiteDemandee: quantiteDemandee,
            emplacement: emplacement,
            dateCreation: now,
            etat: CourierRequestStatus.creee,
            produitNom: Value(produitNom),
            produitDescription: Value(produitDescription),
            produitImageUrl: Value(produitImageUrl),
          ),
        );

    AppLogger.event(
      'Demande coursier créée : $id (coursier $coursierId, produit $productLineId)',
      tag: 'CourierRepository',
    );

    return (await findById(id))!;
  }

  @override
  Future<CourierRequest?> findById(String requestId) async {
    final row = await (_database.select(
      _database.courierRequestsTable,
    )..where((tbl) => tbl.id.equals(requestId)))
        .getSingleOrNull();
    return row == null ? null : _toRequest(row);
  }

  @override
  Future<List<CourierRequest>> listForCoursier(String coursierId) async {
    final rows = await (_database.select(_database.courierRequestsTable)
          ..where((tbl) => tbl.coursierId.equals(coursierId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.dateCreation)]))
        .get();
    return rows.map(_toRequest).toList();
  }

  @override
  Future<List<CourierRequest>> listForPreparateur(String preparateurId) async {
    final rows = await (_database.select(_database.courierRequestsTable)
          ..where((tbl) => tbl.preparateurId.equals(preparateurId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.dateCreation)]))
        .get();
    return rows.map(_toRequest).toList();
  }

  @override
  Future<List<CourierRequest>> listAll() async {
    final rows = await (_database.select(_database.courierRequestsTable)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.dateCreation)]))
        .get();
    return rows.map(_toRequest).toList();
  }

  @override
  Future<int> countOpenRequestsFor(String coursierId) async {
    final rows = await (_database.select(
      _database.courierRequestsTable,
    )..where((tbl) => tbl.coursierId.equals(coursierId)))
        .get();
    return rows.map(_toRequest).where((r) => r.estOuverte).length;
  }

  @override
  Future<void> updateStatus({
    required String requestId,
    required CourierRequestStatus etat,
    CourierRequestResult? resultat,
    DateTime? dateAcceptation,
    DateTime? dateTraitement,
    DateTime? dateCloture,
  }) async {
    await (_database.update(_database.courierRequestsTable)
          ..where((tbl) => tbl.id.equals(requestId)))
        .write(
      CourierRequestsTableCompanion(
        etat: Value(etat),
        resultat: resultat == null ? const Value.absent() : Value(resultat),
        dateAcceptation: dateAcceptation == null
            ? const Value.absent()
            : Value(dateAcceptation),
        dateTraitement: dateTraitement == null
            ? const Value.absent()
            : Value(dateTraitement),
        dateCloture:
            dateCloture == null ? const Value.absent() : Value(dateCloture),
      ),
    );
    AppLogger.event(
      'Demande $requestId → état $etat',
      tag: 'CourierRepository',
    );
  }

  @override
  Future<void> upsertFromRemote(CourierRequest request) async {
    await _database.into(_database.courierRequestsTable).insertOnConflictUpdate(
          CourierRequestsTableCompanion.insert(
            id: request.id,
            preparateurId: request.preparateurId,
            coursierId: request.coursierId,
            tourId: request.tourId,
            productLineId: request.productLineId,
            quantiteDemandee: request.quantiteDemandee,
            emplacement: request.emplacement,
            dateCreation: request.dateCreation,
            etat: request.etat,
            resultat: Value(request.resultat),
            dateAcceptation: Value(request.dateAcceptation),
            dateTraitement: Value(request.dateTraitement),
            dateCloture: Value(request.dateCloture),
            produitNom: Value(request.produitNom),
            produitDescription: Value(request.produitDescription),
            produitImageUrl: Value(request.produitImageUrl),
          ),
        );
  }

  @override
  Future<void> delete(String requestId) async {
    await (_database.delete(
      _database.courierRequestsTable,
    )..where((tbl) => tbl.id.equals(requestId)))
        .go();
    AppLogger.event('Demande $requestId supprimée', tag: 'CourierRepository');
  }

  CourierRequest _toRequest(CourierRequestsTableData row) {
    return CourierRequest(
      id: row.id,
      preparateurId: row.preparateurId,
      coursierId: row.coursierId,
      tourId: row.tourId,
      productLineId: row.productLineId,
      quantiteDemandee: row.quantiteDemandee,
      emplacement: row.emplacement,
      dateCreation: row.dateCreation,
      etat: row.etat,
      resultat: row.resultat,
      dateAcceptation: row.dateAcceptation,
      dateTraitement: row.dateTraitement,
      dateCloture: row.dateCloture,
      produitNom: row.produitNom,
      produitDescription: row.produitDescription,
      produitImageUrl: row.produitImageUrl,
    );
  }
}
