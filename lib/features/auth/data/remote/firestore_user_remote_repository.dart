import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/remote/user_remote_repository.dart';

/// Implémentation réelle de [UserRemoteRepository], adossée à Firestore.
///
/// `.timeout(...)` sur chaque appel réseau : sans lui, `push` (appelé et
/// ATTENDU par `SyncingUserRepository.create/setActive/resetPassword`
/// avant de rendre la main à l'écran) bloquerait indéfiniment la création
/// d'un compte si Firestore ne répond jamais — même raison que dans
/// `FirestoreTourRemoteSource`.
class FirestoreUserRemoteRepository implements UserRemoteRepository {
  FirestoreUserRemoteRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static const _collection = 'users';

  @override
  Future<void> push(UserRemoteRecord record) async {
    await _firestore
        .collection(_collection)
        .doc(record.id)
        .set({
          'identifiant': record.identifiant,
          'nomAffichage': record.nomAffichage,
          'role': record.role.name,
          'actif': record.actif,
          'motDePasseHash': record.motDePasseHash,
          'motDePasseSel': record.motDePasseSel,
          'creeLe': record.creeLe.toIso8601String(),
        })
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<List<UserRemoteRecord>> pullAll() async {
    final snapshot = await _firestore
        .collection(_collection)
        .get()
        .timeout(const Duration(seconds: 20));
    return [
      for (final doc in snapshot.docs) _fromDoc(doc.id, doc.data()),
    ];
  }

  UserRemoteRecord _fromDoc(String id, Map<String, dynamic> data) {
    return UserRemoteRecord(
      id: id,
      identifiant: data['identifiant'] as String,
      nomAffichage: data['nomAffichage'] as String,
      role: UserRole.values.byName(data['role'] as String),
      actif: data['actif'] as bool,
      motDePasseHash: data['motDePasseHash'] as String,
      motDePasseSel: data['motDePasseSel'] as String,
      creeLe: DateTime.parse(data['creeLe'] as String),
    );
  }
}
