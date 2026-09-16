import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genesis_picking/features/warehouse_location/data/remote/brand_warehouse_location_remote_repository.dart';

/// Implémentation réelle de [BrandWarehouseLocationRemoteRepository],
/// adossée à Firestore — même principe que
/// `FirestoreUserRemoteRepository`.
///
/// `.timeout(...)` sur chaque appel réseau : même raison que partout
/// ailleurs dans ce projet (voir `FirestoreTourRemoteSource`) — sans lui,
/// un appel resterait bloqué indéfiniment si Firestore ne répond jamais.
///
/// IMPORTANT — cette collection (`marque_emplacements`) doit avoir son
/// propre bloc `match` dans `firestore.rules`, déployé
/// (`firebase deploy --only firestore:rules`), sinon chaque écriture
/// échoue silencieusement en `permission-denied` (voir `CLAUDE.md`,
/// section "Real cross-device sync" — piège déjà rencontré deux fois sur
/// ce projet).
class FirestoreBrandWarehouseLocationRemoteRepository
    implements BrandWarehouseLocationRemoteRepository {
  FirestoreBrandWarehouseLocationRemoteRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const _collection = 'marque_emplacements';

  @override
  Future<void> push(BrandWarehouseLocationRemoteRecord record) async {
    await _firestore
        .collection(_collection)
        .doc(record.id)
        .set({
          'marque': record.marque,
          'emplacement': record.emplacement,
        })
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> deleteRemote(String id) async {
    await _firestore
        .collection(_collection)
        .doc(id)
        .delete()
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<List<BrandWarehouseLocationRemoteRecord>> pullAll() async {
    final snapshot = await _firestore
        .collection(_collection)
        .get()
        .timeout(const Duration(seconds: 20));
    return [
      for (final doc in snapshot.docs) _fromDoc(doc.id, doc.data()),
    ];
  }

  BrandWarehouseLocationRemoteRecord _fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return BrandWarehouseLocationRemoteRecord(
      id: id,
      marque: data['marque'] as String,
      emplacement: data['emplacement'] as String,
    );
  }
}
