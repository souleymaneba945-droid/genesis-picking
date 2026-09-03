import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_repository.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Implémentation en mémoire de [TourRepository], utilisée uniquement
/// par les tests unitaires — permet de tester [TourService] sans
/// dépendre de Drift.
class FakeTourRepository implements TourRepository {
  final Map<String, Tour> _tours = {};
  final Map<String, int> _productLineCounts = {};

  /// Nombre d'appels réels à [saveDownloadedTour] — utilisé par les
  /// tests pour vérifier qu'un second téléchargement n'écrit pas deux
  /// fois (protection contre les doublons).
  int saveCallCount = 0;

  @override
  Future<List<Tour>> listForPreparateur(String preparateurId) async {
    return _tours.values
        .where((tour) => tour.preparateurId == preparateurId)
        .toList();
  }

  @override
  Future<List<Tour>> listAll() async => _tours.values.toList();

  @override
  Future<Tour?> findById(String tourId) async => _tours[tourId];

  @override
  Future<void> registerAvailableTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
  }) async {
    if (_tours.containsKey(tourId)) return;
    _tours[tourId] = Tour(
      id: tourId,
      numeroTournee: numeroTournee,
      preparateurId: preparateurId,
      dateCreation: DateTime.now(),
      statut: TourStatus.disponible,
      etatSynchronisation: TourSyncState.enAttenteSynchronisation,
      nombreTotalProduits: 0,
      produitsTraites: 0,
    );
  }

  @override
  Future<Tour> saveDownloadedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  }) async {
    final existing = _tours[tourId];
    if (existing != null && existing.estTeleChargeeLocalement) {
      return existing;
    }

    saveCallCount++;
    final tour = Tour(
      id: tourId,
      numeroTournee: numeroTournee,
      preparateurId: preparateurId,
      dateCreation: existing?.dateCreation ?? DateTime.now(),
      dateTelechargement: DateTime.now(),
      statut: TourStatus.telechargee,
      etatSynchronisation: TourSyncState.enAttenteSynchronisation,
      nombreTotalProduits: produits.length,
      produitsTraites: 0,
    );
    _tours[tourId] = tour;
    _productLineCounts[tourId] = produits.length;
    return tour;
  }

  @override
  Future<int> countProductLines(String tourId) async {
    return _productLineCounts[tourId] ?? 0;
  }

  @override
  Future<void> updateStatus({
    required String tourId,
    required TourStatus statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final tour = _tours[tourId];
    if (tour == null) return;
    _tours[tourId] = tour.copyWith(
      statut: statut,
      dateDebut: dateDebut,
      dateFin: dateFin,
    );
  }

  @override
  Future<void> updateProgress({
    required String tourId,
    required int produitsTraites,
  }) async {
    final tour = _tours[tourId];
    if (tour == null) return;
    _tours[tourId] = tour.copyWith(produitsTraites: produitsTraites);
  }

  @override
  Future<void> reassignPreparateur({
    required String tourId,
    required String newPreparateurId,
  }) async {
    final tour = _tours[tourId];
    if (tour == null) return;
    _tours[tourId] = Tour(
      id: tour.id,
      numeroTournee: tour.numeroTournee,
      preparateurId: newPreparateurId,
      dateCreation: tour.dateCreation,
      dateTelechargement: tour.dateTelechargement,
      statut: tour.statut,
      etatSynchronisation: tour.etatSynchronisation,
      nombreTotalProduits: tour.nombreTotalProduits,
      produitsTraites: tour.produitsTraites,
      dateSynchronisation: tour.dateSynchronisation,
    );
  }

  @override
  Future<void> markSynchronized(String tourId) async {
    final tour = _tours[tourId];
    if (tour == null) return;
    _tours[tourId] = tour.copyWith(
      etatSynchronisation: TourSyncState.synchronisee,
      dateSynchronisation: DateTime.now(),
    );
  }

  @override
  Future<void> delete(String tourId) async {
    _tours.remove(tourId);
    _productLineCounts.remove(tourId);
  }
}
