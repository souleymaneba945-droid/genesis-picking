import 'dart:async';

import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';

/// Source distante entièrement contrôlable par les tests : permet de
/// simuler un contenu précis, une erreur réseau, ou un nombre d'appels.
class FakeTourRemoteSource implements TourRemoteSource {
  FakeTourRemoteSource({this.tours = const []});

  List<TourDownloadPayload> tours;

  /// Si non nul, [fetchTourContent] lève cette erreur au lieu de
  /// renvoyer un contenu — simule une coupure réseau (Processus 2).
  Object? networkErrorToThrow;

  int fetchCallCount = 0;

  final _streamController =
      StreamController<List<({String tourId, String numeroTournee})>>.broadcast();

  @override
  Future<List<({String tourId, String numeroTournee})>> listAvailableTours(
    String preparateurId,
  ) async {
    return tours
        .where((tour) => tour.preparateurId == preparateurId)
        .map((tour) => (tourId: tour.tourId, numeroTournee: tour.numeroTournee))
        .toList();
  }

  @override
  Stream<List<({String tourId, String numeroTournee})>> watchAvailableTours(
    String preparateurId,
  ) {
    return _streamController.stream;
  }

  /// Simule un événement Firestore "en direct" (nouvelle tournée
  /// importée ailleurs) — pousse manuellement une liste sur le flux
  /// écouté par [watchAvailableTours], pour les tests de synchronisation
  /// en direct (voir `TourService.watchTours`).
  void emitAvailableTours(
    List<({String tourId, String numeroTournee})> entries,
  ) {
    _streamController.add(entries);
  }

  /// Simule une panne du flux distant — `TourService.watchTours` doit
  /// alors continuer avec les données locales déjà connues, jamais
  /// interrompre le flux qu'il renvoie à l'écran.
  void emitWatchError(Object error) {
    _streamController.addError(error, StackTrace.current);
  }

  @override
  Future<TourDownloadPayload> fetchTourContent(String tourId) async {
    fetchCallCount++;
    if (networkErrorToThrow != null) {
      throw networkErrorToThrow!;
    }
    return tours.firstWhere((tour) => tour.tourId == tourId);
  }
}
