import 'package:genesis_picking/core/sync/sync_event.dart';
import 'package:genesis_picking/core/sync/sync_queue.dart';

/// Implémentation en mémoire de [SyncEventSink], pour vérifier dans les
/// tests que [TourService] dépose bien les événements attendus, sans
/// dépendre de Drift.
class FakeSyncEventSink implements SyncEventSink {
  final List<({String eventType, String payload, SyncPriority priority})>
  enqueued = [];

  @override
  Future<String> enqueue({
    required String eventType,
    required String payload,
    SyncPriority priority = SyncPriority.normale,
  }) async {
    enqueued.add((eventType: eventType, payload: payload, priority: priority));
    return 'fake-event-${enqueued.length}';
  }
}
