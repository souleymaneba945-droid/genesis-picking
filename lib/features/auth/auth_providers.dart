import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/sync/firestore/firestore_providers.dart';
import 'package:genesis_picking/features/auth/data/auth_service.dart';
import 'package:genesis_picking/features/auth/data/database_seeder.dart';
import 'package:genesis_picking/features/auth/data/drift_user_repository.dart';
import 'package:genesis_picking/features/auth/data/login_attempt_tracker.dart';
import 'package:genesis_picking/features/auth/data/remote/firestore_user_remote_repository.dart';
import 'package:genesis_picking/features/auth/data/remote/user_remote_repository.dart';
import 'package:genesis_picking/features/auth/data/syncing_user_repository.dart';
import 'package:genesis_picking/features/auth/data/user_pull_sync.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';

/// Point d'échange des comptes avec le serveur central (voir
/// `MODULE_SYNC_REEL.md`). `FirestoreUserRemoteRepository` maintenant que
/// Firebase est configuré — remplace `NoUserRemoteRepository` (utilisée
/// par les tests, qui n'ont pas besoin de Firebase).
final userRemoteRepositoryProvider = Provider<UserRemoteRepository>((ref) {
  return FirestoreUserRemoteRepository(ref.watch(firestoreProvider));
});

/// Dépôt des comptes utilisateurs — implémentation Drift branchée sur la
/// base locale unique posée au Module 1, enveloppée par
/// [SyncingUserRepository] pour que chaque écriture (création,
/// activation, réinitialisation) soit aussi transmise au serveur
/// central. La lecture (connexion) reste 100% locale, inchangée.
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return SyncingUserRepository(
    DriftUserRepository(ref.watch(localDatabaseProvider)),
    ref.watch(userRemoteRepositoryProvider),
  );
});

/// Récupère, au démarrage, tous les comptes connus du serveur — voir
/// `SplashScreen`.
final userPullSyncProvider = Provider<UserPullSync>((ref) {
  return UserPullSync(
    ref.watch(userRepositoryProvider),
    ref.watch(userRemoteRepositoryProvider),
  );
});

/// Un seul tracker de tentatives pour toute la durée de vie de
/// l'application (voir `login_attempt_tracker.dart`).
final loginAttemptTrackerProvider = Provider<LoginAttemptTracker>((ref) {
  return LoginAttemptTracker();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    userRepository: ref.watch(userRepositoryProvider),
    attemptTracker: ref.watch(loginAttemptTrackerProvider),
  );
});

final databaseSeederProvider = Provider<DatabaseSeeder>((ref) {
  return DatabaseSeeder(ref.watch(userRepositoryProvider));
});
