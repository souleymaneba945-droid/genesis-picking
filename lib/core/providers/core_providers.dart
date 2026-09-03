import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/activity/activity_log.dart';
import 'package:genesis_picking/core/activity/drift_activity_log_repository.dart';
import 'package:genesis_picking/core/session/session_manager.dart';
import 'package:genesis_picking/core/session/user_session.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/core/sync/network_monitor.dart';
import 'package:genesis_picking/core/sync/sync_manager.dart';
import 'package:genesis_picking/core/sync/sync_queue.dart';

/// Providers transverses du socle applicatif.
///
/// Regroupés ici volontairement (Module 1) car ils forment l'ossature
/// partagée par tous les futurs modules. Chaque module métier créera ses
/// propres providers dans son propre dossier `features/<module>/`.

/// Instance unique de la base de données locale pour toute la durée de vie
/// de l'application.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final syncQueueProvider = Provider<SyncQueue>((ref) {
  return SyncQueue(ref.watch(localDatabaseProvider));
});

/// Historique d'activité (picking + coursier) — voir `core/activity/`.
/// Exposé comme [ActivityLogRepository] complet ici ; les services métier
/// ne reçoivent que la vue restreinte [ActivityLogSink] à l'injection.
final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  return DriftActivityLogRepository(ref.watch(localDatabaseProvider));
});

/// Instance unique de [NetworkMonitor] (Module 6), partagée par
/// [SyncManager] (indicateur d'interface) et par `SyncService`
/// (`features/sync/`, moteur réel) — une seule souscription à
/// `connectivity_plus` pour toute l'application.
final networkMonitorProvider = Provider<NetworkMonitor>((ref) {
  final monitor = NetworkMonitor();
  ref.onDispose(monitor.dispose);
  return monitor;
});

final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager(
    syncQueue: ref.watch(syncQueueProvider),
    networkMonitor: ref.watch(networkMonitorProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager();
});

/// Session actuellement active, `null` si personne n'est connecté.
///
/// Notifier explicite (plutôt qu'un simple Provider) car la session change
/// dans le temps : connexion, déconnexion, restauration au démarrage.
class SessionNotifier extends Notifier<UserSession?> {
  @override
  UserSession? build() => null;

  Future<void> restore() async {
    final manager = ref.read(sessionManagerProvider);
    state = await manager.restoreSession();
  }

  /// Corrige le nom d'affichage d'une session restaurée — [restore] ne
  /// connaît que l'identifiant technique (`SessionManager` reste dans
  /// `core/`, sans dépendance vers `features/auth/`) ; c'est à l'appelant
  /// (voir `SplashScreen`, seul endroit qui appelle [restore]) de fournir
  /// le vrai nom une fois le compte relu localement. Sans effet si aucune
  /// session n'est active ou si son identifiant a changé entre-temps
  /// (déconnexion pendant la relecture, par exemple).
  void refreshDisplayName(String userId, String displayName) {
    final current = state;
    if (current == null || current.userId != userId) return;
    state = UserSession(
      userId: current.userId,
      displayName: displayName,
      role: current.role,
      token: current.token,
    );
  }

  Future<void> open(UserSession session) async {
    final manager = ref.read(sessionManagerProvider);
    final result = await manager.openSession(session);
    result.when(
      success: (value) => state = value,
      failure: (_) => state = null,
    );
  }

  Future<void> close() async {
    final manager = ref.read(sessionManagerProvider);
    await manager.closeSession();
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, UserSession?>(
  SessionNotifier.new,
);
