import 'package:genesis_picking/core/activity/activity_level.dart';

/// Une ligne de l'historique d'activité, telle qu'affichée à l'écran.
class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.userId,
    required this.level,
    required this.message,
    required this.dateHeure,
  });

  final String id;
  final String userId;
  final ActivityLevel level;
  final String message;
  final DateTime dateHeure;
}
