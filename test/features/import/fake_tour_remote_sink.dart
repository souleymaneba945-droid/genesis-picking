import 'package:genesis_picking/features/tours/data/tour_remote_sink.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';

/// Implémentation en mémoire de [TourRemoteSink], pour vérifier que
/// [ImportEngine] transmet bien une tournée importée avec succès, sans
/// dépendre de Firebase.
class FakeTourRemoteSink implements TourRemoteSink {
  final List<
      ({
        String tourId,
        String numeroTournee,
        String preparateurId,
        List<TourProductPayload> produits,
      })> pushed = [];

  /// Simule un échec réseau — [ImportEngine] doit continuer à considérer
  /// l'import comme réussi malgré cet échec (voir le test correspondant).
  bool shouldThrow = false;

  final List<String> deleted = [];

  @override
  Future<void> pushImportedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  }) async {
    if (shouldThrow) {
      throw Exception('Pas de réseau (simulé)');
    }
    pushed.add((
      tourId: tourId,
      numeroTournee: numeroTournee,
      preparateurId: preparateurId,
      produits: produits,
    ));
  }

  @override
  Future<void> deleteTour(String tourId) async {
    if (shouldThrow) {
      throw Exception('Pas de réseau (simulé)');
    }
    deleted.add(tourId);
  }
}
