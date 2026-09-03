import 'dart:async';

import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/sync/network_monitor.dart';
import 'package:genesis_picking/core/sync/sync_queue.dart';

/// État de synchronisation affiché à l'utilisateur (indicateur discret,
/// voir Document UX/UI, section 8 : jamais bloquant, jamais intrusif).
enum SyncState { synced, pending, syncing, offline, error }

/// Indicateur d'état de synchronisation pour l'interface (icône
/// discrète de l'AppBar — voir `AppScaffold`/`SyncStatusIndicator`).
///
/// Posé comme structure au Module 1, avec un [triggerSync] qui ne faisait
/// que consulter la file sans rien transmettre. Au Module 6, la
/// détection réseau elle-même a été extraite dans [NetworkMonitor] (seule
/// classe du projet à parler à `connectivity_plus`) ; ce manager s'appuie
/// désormais dessus. Le VÉRITABLE moteur de transmission
/// (`SyncService`, dans `features/sync/`) est un consommateur INDÉPENDANT
/// du même [NetworkMonitor] — pas de dépendance de `core/` vers
/// `features/`, conformément à l'architecture posée au Module 1.
/// [triggerSync] reste donc un indicateur, pas le moteur lui-même.
class SyncManager {
  SyncManager({required SyncQueue syncQueue, NetworkMonitor? networkMonitor})
    : _syncQueue = syncQueue,
      _networkMonitor = networkMonitor ?? NetworkMonitor();

  final SyncQueue _syncQueue;
  final NetworkMonitor _networkMonitor;

  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();
  StreamSubscription<bool>? _connectivitySubscription;

  Stream<SyncState> get stateStream => _stateController.stream;
  SyncState _currentState = SyncState.offline;
  SyncState get currentState => _currentState;

  /// À appeler une seule fois au démarrage de l'application.
  Future<void> initialize() async {
    await _networkMonitor.start();

    _connectivitySubscription = _networkMonitor.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) {
        AppLogger.info(
          'Connexion réseau détectée, synchronisation possible',
          tag: 'SyncManager',
        );
        unawaited(triggerSync());
      } else {
        _emitState(SyncState.offline);
      }
    });

    _emitState(_networkMonitor.isOnline ? SyncState.pending : SyncState.offline);
  }

  /// Rafraîchit l'indicateur d'après la file locale. Le déclenchement
  /// réel de la transmission (Module 6) est assuré indépendamment par
  /// `SyncService`, qui écoute lui aussi [NetworkMonitor].
  Future<void> triggerSync() async {
    _emitState(SyncState.syncing);
    final pending = await _syncQueue.pendingEvents();
    _emitState(pending.isEmpty ? SyncState.synced : SyncState.pending);
  }

  void _emitState(SyncState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _stateController.close();
  }
}
