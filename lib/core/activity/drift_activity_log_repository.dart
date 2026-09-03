import 'package:drift/drift.dart';
import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/activity/activity_log.dart';
import 'package:genesis_picking/core/activity/activity_log_entry.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:uuid/uuid.dart';

/// Implémentation Drift de [ActivityLogRepository].
class DriftActivityLogRepository implements ActivityLogRepository {
  DriftActivityLogRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  @override
  Future<void> record({
    required String userId,
    required ActivityLevel level,
    required String message,
  }) async {
    await _database.into(_database.activityLogTable).insert(
          ActivityLogTableCompanion.insert(
            id: _uuid.v4(),
            userId: userId,
            level: level,
            message: message,
            dateHeure: DateTime.now(),
          ),
        );
  }

  @override
  Future<List<ActivityLogEntry>> listForUser(
    String userId, {
    int limit = 100,
  }) async {
    final rows = await (_database.select(_database.activityLogTable)
          ..where((tbl) => tbl.userId.equals(userId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.dateHeure)])
          ..limit(limit))
        .get();

    return [
      for (final row in rows)
        ActivityLogEntry(
          id: row.id,
          userId: row.userId,
          level: row.level,
          message: row.message,
          dateHeure: row.dateHeure,
        ),
    ];
  }

  @override
  Future<void> purgeForUser(String userId) async {
    final supprimees = await (_database.delete(_database.activityLogTable)
          ..where((tbl) => tbl.userId.equals(userId)))
        .go();
    AppLogger.event(
      'Historique d\'activité purgé pour $userId ($supprimees entrées)',
      tag: 'ActivityLog',
    );
  }
}
