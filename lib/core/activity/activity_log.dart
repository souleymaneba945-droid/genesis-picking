import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/activity/activity_log_entry.dart';

/// Point d'entrée en écriture pour les modules métier (`PickingService`,
/// `CourierService`) — même principe que [SyncEventSink]
/// (`core/sync/sync_queue.dart`) : un service dépose un évènement sans
/// jamais connaître le stockage concret, ni pouvoir lire ou purger
/// l'historique de qui que ce soit.
abstract interface class ActivityLogSink {
  Future<void> record({
    required String userId,
    required ActivityLevel level,
    required String message,
  });
}

/// Lecture et purge — utilisé uniquement par les écrans d'historique
/// (jamais par un service métier, même logique de séparation que
/// `SyncQueue` / `SyncRepository`).
abstract interface class ActivityLogRepository implements ActivityLogSink {
  /// Les entrées de [userId], les plus récentes en premier.
  Future<List<ActivityLogEntry>> listForUser(String userId, {int limit = 100});

  /// Efface tout l'historique de [userId] — n'a aucun effet sur les
  /// tournées, produits ou demandes coursier eux-mêmes.
  Future<void> purgeForUser(String userId);
}
