import 'package:genesis_picking/core/sync/sync_event.dart';
import 'package:genesis_picking/features/sync/data/sync_operation.dart';
import 'package:genesis_picking/features/sync/data/sync_repository.dart';
import 'package:genesis_picking/features/sync/data/sync_run_log.dart';

/// Implémentation en mémoire de [SyncRepository], utilisée uniquement par
/// les tests unitaires — permet de tester `SyncService` sans dépendre de
/// Drift.
class FakeSyncRepository implements SyncRepository {
  final Map<String, SyncOperation> _operations = {};
  final Map<String, SyncRunLog> _runLogs = {};
  int _runSequence = 0;

  static const _priorityRank = {
    SyncPriority.haute: 0,
    SyncPriority.normale: 1,
    SyncPriority.basse: 2,
  };

  void seed(SyncOperation operation) {
    _operations[operation.id] = operation;
  }

  @override
  Future<List<SyncOperation>> fetchOperationsToProcess() async {
    final list =
        _operations.values
            .where(
              (op) =>
                  op.status == SyncEventStatus.pending ||
                  op.status == SyncEventStatus.retrying,
            )
            .toList()
          ..sort((a, b) {
            final byPriority = _priorityRank[a.priority]!.compareTo(
              _priorityRank[b.priority]!,
            );
            if (byPriority != 0) return byPriority;
            return a.createdAt.compareTo(b.createdAt);
          });
    return list;
  }

  @override
  Future<int> countPending() async {
    return _operations.values
        .where(
          (op) =>
              op.status == SyncEventStatus.pending ||
              op.status == SyncEventStatus.retrying,
        )
        .length;
  }

  @override
  Future<SyncOperation?> findById(String operationId) async =>
      _operations[operationId];

  @override
  Future<void> markInProgress(String operationId) async {
    _update(operationId, status: SyncEventStatus.inProgress);
  }

  @override
  Future<void> markSynced(String operationId) async {
    _update(operationId, status: SyncEventStatus.synced);
  }

  @override
  Future<void> markRetrying({
    required String operationId,
    required int attemptCount,
    required String error,
  }) async {
    _update(
      operationId,
      status: SyncEventStatus.retrying,
      attemptCount: attemptCount,
      error: error,
    );
  }

  @override
  Future<void> markFailed({
    required String operationId,
    required int attemptCount,
    required String error,
  }) async {
    _update(
      operationId,
      status: SyncEventStatus.failed,
      attemptCount: attemptCount,
      error: error,
    );
  }

  void _update(
    String operationId, {
    required SyncEventStatus status,
    int? attemptCount,
    String? error,
  }) {
    final existing = _operations[operationId];
    if (existing == null) return;
    _operations[operationId] = existing.copyWith(
      status: status,
      attemptCount: attemptCount,
      lastAttemptAt: DateTime.now(),
      lastError: error,
    );
  }

  @override
  Future<String> startRunLog() async {
    _runSequence++;
    final id = 'run-$_runSequence';
    _runLogs[id] = SyncRunLog(
      id: id,
      startedAt: DateTime.now(),
      itemsProcessed: 0,
      itemsSucceeded: 0,
      itemsFailed: 0,
    );
    return id;
  }

  @override
  Future<void> finishRunLog({
    required String runLogId,
    required int itemsProcessed,
    required int itemsSucceeded,
    required int itemsFailed,
    String? errorSummary,
  }) async {
    final existing = _runLogs[runLogId];
    if (existing == null) return;
    _runLogs[runLogId] = SyncRunLog(
      id: existing.id,
      startedAt: existing.startedAt,
      finishedAt: DateTime.now(),
      itemsProcessed: itemsProcessed,
      itemsSucceeded: itemsSucceeded,
      itemsFailed: itemsFailed,
      errorSummary: errorSummary,
    );
  }

  @override
  Future<SyncRunLog?> lastFinishedRun() async {
    final finished = _runLogs.values.where((run) => !run.estEnCours).toList()
      ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));
    return finished.isEmpty ? null : finished.first;
  }

  List<SyncOperation> get all => _operations.values.toList();
}
