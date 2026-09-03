import 'package:genesis_picking/features/tours/data/tour_remote_sink.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';

/// Implémentation en mémoire de [TourRemoteSink], pour vérifier dans les
/// tests de [TourService] que suppression locale et suppression serveur
/// vont toujours de pair — même principe que les autres fakes de ce
/// dossier.
class FakeTourRemoteSink implements TourRemoteSink {
  final List<String> deleted = [];

  @override
  Future<void> pushImportedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  }) async {}

  @override
  Future<void> deleteTour(String tourId) async {
    deleted.add(tourId);
  }
}
