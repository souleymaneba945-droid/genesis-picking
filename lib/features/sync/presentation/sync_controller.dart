import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/features/sync/data/sync_run_log.dart';
import 'package:genesis_picking/features/sync/sync_providers.dart';

/// État affiché par l'écran Synchronisation — exactement les quatre
/// informations demandées par la Directive.
class SyncScreenState {
  const SyncScreenState({
    required this.lastRun,
    required this.pendingCount,
    required this.isOnline,
    required this.isRunning,
  });

  final SyncRunLog? lastRun;
  final int pendingCount;
  final bool isOnline;
  final bool isRunning;
}

/// Contrôleur de l'écran Synchronisation. Ne contient aucune logique
/// métier : délègue entièrement à `SyncService`.
class SyncController extends AsyncNotifier<SyncScreenState> {
  @override
  Future<SyncScreenState> build() => _loadState();

  Future<SyncScreenState> _loadState({bool isRunning = false}) async {
    final service = ref.read(syncServiceProvider);
    final networkMonitor = ref.read(networkMonitorProvider);
    final lastRun = await service.lastFinishedRun();
    final pending = await service.pendingCount();
    return SyncScreenState(
      lastRun: lastRun,
      pendingCount: pending,
      isOnline: networkMonitor.isOnline,
      isRunning: isRunning,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadState);
  }

  /// Bouton "Synchroniser maintenant" (Directive : "utile pour les
  /// tests"). N'empêche jamais l'utilisateur de continuer à utiliser le
  /// reste de l'application pendant ce temps — cet appel ne bloque que
  /// l'écran Synchronisation lui-même, pas le reste de l'app.
  Future<void> synchronizeNow() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        SyncScreenState(
          lastRun: current.lastRun,
          pendingCount: current.pendingCount,
          isOnline: current.isOnline,
          isRunning: true,
        ),
      );
    }
    await ref.read(syncServiceProvider).synchronizeNow();
    await refresh();
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncScreenState>(
      SyncController.new,
    );
