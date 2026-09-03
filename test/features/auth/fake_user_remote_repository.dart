import 'package:genesis_picking/features/auth/data/remote/user_remote_repository.dart';

/// Implémentation en mémoire de [UserRemoteRepository], pour vérifier
/// dans les tests que [SyncingUserRepository]/[UserPullSync] transmettent
/// et récupèrent bien les comptes attendus, sans dépendre de Firestore.
class FakeUserRemoteRepository implements UserRemoteRepository {
  final List<UserRemoteRecord> pushed = [];

  /// Comptes que [pullAll] doit renvoyer.
  List<UserRemoteRecord> serverRecords = [];

  /// Si `true`, [push] et [pullAll] lèvent une exception — simule une
  /// panne réseau.
  bool shouldThrow = false;

  @override
  Future<void> push(UserRemoteRecord record) async {
    if (shouldThrow) {
      throw Exception('Panne réseau simulée');
    }
    pushed.add(record);
  }

  @override
  Future<List<UserRemoteRecord>> pullAll() async {
    if (shouldThrow) {
      throw Exception('Panne réseau simulée');
    }
    return serverRecords;
  }
}
