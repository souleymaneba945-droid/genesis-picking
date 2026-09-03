import 'package:drift/drift.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_repository.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:uuid/uuid.dart';

/// Implémentation Drift de [TourRepository].
class DriftTourRepository implements TourRepository {
  DriftTourRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  @override
  Future<List<Tour>> listForPreparateur(String preparateurId) async {
    final rows = await (_database.select(
      _database.toursTable,
    )..where((tbl) => tbl.preparateurId.equals(preparateurId)))
        .get();
    return rows.map(_toTour).toList();
  }

  @override
  Future<List<Tour>> listAll() async {
    final rows = await _database.select(_database.toursTable).get();
    return rows.map(_toTour).toList();
  }

  @override
  Future<Tour?> findById(String tourId) async {
    final row = await (_database.select(
      _database.toursTable,
    )..where((tbl) => tbl.id.equals(tourId)))
        .getSingleOrNull();
    return row == null ? null : _toTour(row);
  }

  @override
  Future<void> registerAvailableTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
  }) async {
    final existing = await findById(tourId);
    if (existing != null) {
      // Protection contre les doublons (Processus 2) : une tournée déjà
      // connue localement — disponible ou déjà téléchargée — n'est
      // jamais recréée ni écrasée.
      return;
    }

    await _database.into(_database.toursTable).insert(
          ToursTableCompanion.insert(
            id: tourId,
            numeroTournee: numeroTournee,
            preparateurId: preparateurId,
            dateCreation: DateTime.now(),
            statut: TourStatus.disponible,
            etatSynchronisation: TourSyncState.enAttenteSynchronisation,
            nombreTotalProduits: 0,
          ),
        );
  }

  @override
  Future<Tour> saveDownloadedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  }) async {
    final existing = await findById(tourId);
    if (existing != null && existing.estTeleChargeeLocalement) {
      // Idempotence : un second appel (ex. après coupure réseau juste
      // après un premier succès) ne duplique rien.
      AppLogger.info(
        'Tournée déjà téléchargée, aucune duplication : $tourId',
        tag: 'TourRepository',
      );
      return existing;
    }

    // Écriture atomique : soit la tournée ET toutes ses lignes produits
    // sont enregistrées, soit rien ne l'est — condition nécessaire à une
    // reprise fiable après une coupure en plein téléchargement
    // (Directive Module 3, "permettre une reprise après coupure réseau").
    return _database.transaction(() async {
      final now = DateTime.now();

      await _database.into(_database.toursTable).insertOnConflictUpdate(
            ToursTableCompanion.insert(
              id: tourId,
              numeroTournee: numeroTournee,
              preparateurId: preparateurId,
              dateCreation: now,
              dateTelechargement: Value(now),
              statut: TourStatus.telechargee,
              etatSynchronisation: TourSyncState.enAttenteSynchronisation,
              nombreTotalProduits: produits.length,
            ),
          );

      // On repart d'une liste de lignes vide pour cette tournée avant
      // réinsertion, afin qu'un retry après échec partiel ne laisse
      // jamais de lignes dupliquées ou orphelines.
      await (_database.delete(
        _database.tourProductLinesTable,
      )..where((tbl) => tbl.tourId.equals(tourId)))
          .go();

      // Une seule écriture groupée (`batch`) plutôt qu'une insertion par
      // produit attendue individuellement : sur une tournée de plusieurs
      // dizaines de lignes, chaque `insert()` séparé paie le coût d'un
      // aller-retour SQLite à lui seul — un `batch` les envoie en un seul
      // bloc, sensiblement plus rapide, en particulier sur un téléphone
      // d'entrée de gamme. Reste dans la même transaction englobante donc
      // toujours "tout ou rien" en cas d'échec.
      await _database.batch((batch) {
        batch.insertAll(
          _database.tourProductLinesTable,
          [
            for (final produit in produits)
              TourProductLinesTableCompanion.insert(
                id: _uuid.v4(),
                tourId: tourId,
                ordre: produit.ordre,
                nom: produit.nom,
                quantiteDemandee: produit.quantiteDemandee,
                emplacement: produit.emplacement,
                description: Value(produit.description),
                imageUrl: Value(produit.imageUrl),
              ),
          ],
        );
      });

      AppLogger.event(
        'Tournée téléchargée et stockée localement : $tourId '
        '(${produits.length} produits)',
        tag: 'TourRepository',
      );

      return (await findById(tourId))!;
    });
  }

  @override
  Future<int> countProductLines(String tourId) async {
    final rows = await (_database.select(
      _database.tourProductLinesTable,
    )..where((tbl) => tbl.tourId.equals(tourId)))
        .get();
    return rows.length;
  }

  @override
  Future<void> updateStatus({
    required String tourId,
    required TourStatus statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    await (_database.update(
      _database.toursTable,
    )..where((tbl) => tbl.id.equals(tourId)))
        .write(
      ToursTableCompanion(
        statut: Value(statut),
        dateDebut: dateDebut == null ? const Value.absent() : Value(dateDebut),
        dateFin: dateFin == null ? const Value.absent() : Value(dateFin),
      ),
    );
    AppLogger.event('Tournée $tourId → statut $statut', tag: 'TourRepository');
  }

  @override
  Future<void> updateProgress({
    required String tourId,
    required int produitsTraites,
  }) async {
    await (_database.update(
      _database.toursTable,
    )..where((tbl) => tbl.id.equals(tourId)))
        .write(
      ToursTableCompanion(produitsTraites: Value(produitsTraites)),
    );
  }

  @override
  Future<void> reassignPreparateur({
    required String tourId,
    required String newPreparateurId,
  }) async {
    await (_database.update(
      _database.toursTable,
    )..where((tbl) => tbl.id.equals(tourId)))
        .write(
      ToursTableCompanion(preparateurId: Value(newPreparateurId)),
    );
    AppLogger.event(
      'Tournée $tourId réassignée au préparateur $newPreparateurId',
      tag: 'TourRepository',
    );
  }

  @override
  Future<void> markSynchronized(String tourId) async {
    await (_database.update(
      _database.toursTable,
    )..where((tbl) => tbl.id.equals(tourId)))
        .write(
      ToursTableCompanion(
        etatSynchronisation: const Value(TourSyncState.synchronisee),
        dateSynchronisation: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> delete(String tourId) async {
    await _database.transaction(() async {
      final lignes = await (_database.select(
        _database.tourProductLinesTable,
      )..where((tbl) => tbl.tourId.equals(tourId)))
          .get();
      final ligneIds = lignes.map((l) => l.id).toList();

      if (ligneIds.isNotEmpty) {
        // États de collecte liés (relation un-à-un sur productLineId, voir
        // `PickingProductStatusesTable`) — supprimés d'abord, sinon ils
        // resteraient orphelins après la suppression des lignes produits.
        await (_database.delete(
          _database.pickingProductStatusesTable,
        )..where((tbl) => tbl.productLineId.isIn(ligneIds)))
            .go();
      }
      await (_database.delete(
        _database.tourProductLinesTable,
      )..where((tbl) => tbl.tourId.equals(tourId)))
          .go();
      await (_database.delete(
        _database.toursTable,
      )..where((tbl) => tbl.id.equals(tourId)))
          .go();
    });
    AppLogger.event('Tournée supprimée localement : $tourId', tag: 'TourRepository');
  }

  Tour _toTour(ToursTableData row) {
    return Tour(
      id: row.id,
      numeroTournee: row.numeroTournee,
      preparateurId: row.preparateurId,
      dateCreation: row.dateCreation,
      dateTelechargement: row.dateTelechargement,
      statut: row.statut,
      etatSynchronisation: row.etatSynchronisation,
      nombreTotalProduits: row.nombreTotalProduits,
      produitsTraites: row.produitsTraites,
      dateSynchronisation: row.dateSynchronisation,
      dateDebut: row.dateDebut,
      dateFin: row.dateFin,
    );
  }
}
