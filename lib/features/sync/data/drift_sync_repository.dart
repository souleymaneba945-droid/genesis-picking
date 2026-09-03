import 'package:drift/drift.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/core/sync/sync_event.dart';
import 'package:genesis_picking/features/sync/data/sync_operation.dart';
import 'package:genesis_picking/features/sync/data/sync_repository.dart';
import 'package:genesis_picking/features/sync/data/sync_run_log.dart';
import 'package:uuid/uuid.dart';

/// Implémentation Drift de [SyncRepository].
class DriftSyncRepository implements SyncRepository {
  DriftSyncRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  static const _priorityRank = {
    SyncPriority.haute: 0,
    SyncPriority.normale: 1,
    SyncPriority.basse: 2,
  };

  @override
  Future<List<SyncOperation>> fetchOperationsToProcess() async {
    final rows =
        await (_database.select(_database.syncEventsTable)..where(
              (tbl) =>
                  tbl.status.equalsValue(SyncEventStatus.pending) |
                  tbl.status.equalsValue(SyncEventStatus.retrying),
            ))
            .get();

    final operations = rows.map(_toOperation).toList()
      ..sort((a, b) {
        final priorityComparison = _priorityRank[a.priority]!.compareTo(
          _priorityRank[b.priority]!,
        );
        if (priorityComparison != 0) return priorityComparison;
        return a.createdAt.compareTo(b.createdAt);
      });

    return operations;
  }

  @override
  Future<int> countPending() async {
    final rows = await (_database.select(_database.syncEventsTable)..where(
          (tbl) =>
              tbl.status.equalsValue(SyncEventStatus.pending) |
              tbl.status.equalsValue(SyncEventStatus.retrying),
        ))
        .get();
    return rows.length;
  }

  @override
  Future<SyncOperation?> findById(String operationId) async {
    final row = await (_database.select(
      _database.syncEventsTable,
    )..where((tbl) => tbl.id.equals(operationId))).getSingleOrNull();
    return row == null ? null : _toOperation(row);
  }

  @override
  Future<void> markInProgress(String operationId) {
    return _updateStatus(operationId, SyncEventStatus.inProgress);
  }

  @override
  Future<void> markSynced(String operationId) {
    return _updateStatus(operationId, SyncEventStatus.synced);
  }

  @override
  Future<void> markRetrying({
    required String operationId,
    required int attemptCount,
    required String error,
  }) {
    return _updateStatus(
      operationId,
      SyncEventStatus.retrying,
      attemptCount: attemptCount,
      error: error,
    );
  }

  @override
  Future<void> markFailed({
    required String operationId,
    required int attemptCount,
    required String error,
  }) {
    return _updateStatus(
      operationId,
      SyncEventStatus.failed,
      attemptCount: attemptCount,
      error: error,
    );
  }

  Future<void> _updateStatus(
    String operationId,
    SyncEventStatus status, {
    int? attemptCount,
    String? error,
  }) async {
    await (_database.update(_database.syncEventsTable)
          ..where((tbl) => tbl.id.equals(operationId)))
        .write(
          SyncEventsTableCompanion(
            status: Value(status),
            attemptCount: attemptCount == null
                ? const Value.absent()
                : Value(attemptCount),
            lastAttemptAt: Value(DateTime.now()),
            lastError: error == null ? const Value.absent() : Value(error),
          ),
        );
  }

  @override
  Future<String> startRunLog() async {
    final id = _uuid.v4();
    await _database
        .into(_database.syncRunLogsTable)
        .insert(
          SyncRunLogsTableCompanion.insert(id: id, startedAt: DateTime.now()),
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
    await (_database.update(_database.syncRunLogsTable)
          ..where((tbl) => tbl.id.equals(runLogId)))
        .write(
          SyncRunLogsTableCompanion(
            finishedAt: Value(DateTime.now()),
            itemsProcessed: Value(itemsProcessed),
            itemsSucceeded: Value(itemsSucceeded),
            itemsFailed: Value(itemsFailed),
            errorSummary: errorSummary == null
                ? const Value.absent()
                : Value(errorSummary),
          ),
        );
  }

  @override
  Future<SyncRunLog?> lastFinishedRun() async {
    final row =
        await (_database.select(_database.syncRunLogsTable)
              ..where((tbl) => tbl.finishedAt.isNotNull())
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.finishedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return SyncRunLog(
      id: row.id,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
      itemsProcessed: row.itemsProcessed,
      itemsSucceeded: row.itemsSucceeded,
      itemsFailed: row.itemsFailed,
      errorSummary: row.errorSummary,
    );
  }

  SyncOperation _toOperation(SyncEventsTableData row) {
    return SyncOperation(
      id: row.id,
      eventType: row.eventType,
      payload: row.payload,
      createdAt: row.createdAt,
      status: row.status,
      attemptCount: row.attemptCount,
      priority: row.priority,
      lastAttemptAt: row.lastAttemptAt,
      lastError: row.lastError,
    );
  }
}
