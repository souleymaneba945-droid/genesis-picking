import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';

/// Implémentation réelle de [TourRemoteSource], adossée à Firestore.
///
/// Remplace [NoTourRemoteSource] maintenant qu'un vrai backend existe
/// (voir MODULE_SYNC_REEL.md) : une tournée importée sur UN appareil
/// (via `ImportEngine` + [FirestoreTourRemoteSink]) devient ainsi visible
/// et téléchargeable depuis n'importe quel autre appareil connecté au
/// même compte préparateur — c'est tout le sens de l'opération, [TourService]
/// lui n'a besoin d'aucun changement : il ne connaît que cette interface.
///
/// Chaque appel réseau est borné par un `.timeout(...)` — sans lui, une
/// requête Firestore qui ne répond jamais (réseau instable, coupure en
/// plein vol) laisse l'`await` appelant bloqué indéfiniment ; côté écran
/// (`TourService.downloadTour`/`refreshAvailableTours`), le `try/catch`
/// existant transforme déjà ça en échec propre ("Pas de connexion"), mais
/// seulement si quelque chose finit par être levé — d'où ce timeout, pas
/// optionnel. Découvert le 31/08/2026 : un préparateur signalait l'appli
/// "gelée" pendant un téléchargement de tournée, nécessitant un
/// redémarrage forcé de l'appareil.
class FirestoreTourRemoteSource implements TourRemoteSource {
  FirestoreTourRemoteSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const _toursCollection = 'tours';
  static const _productLinesCollection = 'tour_product_lines';

  @override
  Future<List<({String tourId, String numeroTournee})>> listAvailableTours(
    String preparateurId,
  ) async {
    final snapshot = await _firestore
        .collection(_toursCollection)
        .where('preparateurId', isEqualTo: preparateurId)
        .get()
        .timeout(const Duration(seconds: 20));

    return [
      for (final doc in snapshot.docs)
        (
          tourId: doc.id,
          numeroTournee: (doc.data()['numeroTournee'] as String?) ?? '',
        ),
    ];
  }

  @override
  Stream<List<({String tourId, String numeroTournee})>> watchAvailableTours(
    String preparateurId,
  ) {
    return _firestore
        .collection(_toursCollection)
        .where('preparateurId', isEqualTo: preparateurId)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              (
                tourId: doc.id,
                numeroTournee: (doc.data()['numeroTournee'] as String?) ?? '',
              ),
          ],
        );
  }

  @override
  Future<TourDownloadPayload> fetchTourContent(String tourId) async {
    final tourDoc = await _firestore
        .collection(_toursCollection)
        .doc(tourId)
        .get()
        .timeout(const Duration(seconds: 20));
    final tourData = tourDoc.data();
    if (tourData == null) {
      throw StateError('Tournée introuvable sur le serveur : $tourId');
    }

    final linesSnapshot = await _firestore
        .collection(_productLinesCollection)
        .where('tourId', isEqualTo: tourId)
        .get()
        .timeout(const Duration(seconds: 20));

    // Tri côté client (plutôt qu'un orderBy Firestore) : évite d'exiger un
    // index composite (tourId + ordre) rien que pour ce tri, sur un volume
    // de données (quelques centaines de lignes maximum) où ça ne coûte rien.
    final lignes = linesSnapshot.docs.toList()
      ..sort(
        (a, b) => (a.data()['ordre'] as int).compareTo(b.data()['ordre'] as int),
      );

    final produits = [
      for (final doc in lignes)
        TourProductPayload(
          ordre: doc.data()['ordre'] as int,
          nom: doc.data()['nom'] as String,
          quantiteDemandee: doc.data()['quantiteDemandee'] as int,
          emplacement: (doc.data()['emplacement'] as String?) ?? '',
          description: doc.data()['description'] as String?,
          imageUrl: doc.data()['imageUrl'] as String?,
        ),
    ];

    return TourDownloadPayload(
      tourId: tourId,
      numeroTournee: tourData['numeroTournee'] as String,
      preparateurId: tourData['preparateurId'] as String,
      produits: produits,
    );
  }
}
