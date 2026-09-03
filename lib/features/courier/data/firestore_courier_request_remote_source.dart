import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_remote_source.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Implémentation réelle de [CourierRequestRemoteSource], adossée à
/// Firestore — remplace [NoCourierRequestRemoteSource] maintenant qu'un
/// vrai backend existe (voir `FirestoreCourierRequestRemoteSink`, qui
/// alimente la même collection à la création/mise à jour d'une demande).
///
/// `.timeout(...)` sur l'appel réseau : voir le même choix, pour la même
/// raison (éviter un `await` bloqué indéfiniment sur un réseau qui ne
/// répond jamais), dans `FirestoreTourRemoteSource`.
class FirestoreCourierRequestRemoteSource implements CourierRequestRemoteSource {
  FirestoreCourierRequestRemoteSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const _collection = 'courier_requests';

  @override
  Future<List<CourierRequest>> pullForCoursier(String coursierId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('coursierId', isEqualTo: coursierId)
        .get()
        .timeout(const Duration(seconds: 20));

    return [
      for (final doc in snapshot.docs) _toRequest(doc.id, doc.data()),
    ];
  }

  @override
  Stream<List<CourierRequest>> watchForCoursier(String coursierId) {
    return _firestore
        .collection(_collection)
        .where('coursierId', isEqualTo: coursierId)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs) _toRequest(doc.id, doc.data()),
          ],
        );
  }

  CourierRequest _toRequest(String id, Map<String, dynamic> data) {
    return CourierRequest(
      id: id,
      preparateurId: data['preparateurId'] as String,
      coursierId: data['coursierId'] as String,
      tourId: data['tourId'] as String,
      productLineId: data['productLineId'] as String,
      quantiteDemandee: data['quantiteDemandee'] as int,
      emplacement: (data['emplacement'] as String?) ?? '',
      dateCreation: DateTime.parse(data['dateCreation'] as String),
      etat: CourierRequestStatus.values.byName(data['etat'] as String),
      resultat: (data['resultat'] as String?) == null
          ? null
          : CourierRequestResult.values.byName(data['resultat'] as String),
      dateAcceptation: (data['dateAcceptation'] as String?) == null
          ? null
          : DateTime.parse(data['dateAcceptation'] as String),
      dateTraitement: (data['dateTraitement'] as String?) == null
          ? null
          : DateTime.parse(data['dateTraitement'] as String),
      dateCloture: (data['dateCloture'] as String?) == null
          ? null
          : DateTime.parse(data['dateCloture'] as String),
      produitNom: data['produitNom'] as String?,
      produitDescription: data['produitDescription'] as String?,
      produitImageUrl: data['produitImageUrl'] as String?,
    );
  }
}
