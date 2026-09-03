import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/activity/activity_log.dart';

/// Implémentation en mémoire de [ActivityLogSink], pour vérifier dans les
/// tests que les services métier déposent bien les évènements attendus,
/// sans dépendre de Drift. Partagée par les tests de `PickingService` et
/// `CourierService`, comme [FakeSyncEventSink] l'est pour la file de
/// synchronisation.
class FakeActivityLogSink implements ActivityLogSink {
  final List<({String userId, ActivityLevel level, String message})>
  recorded = [];

  @override
  Future<void> record({
    required String userId,
    required ActivityLevel level,
    required String message,
  }) async {
    recorded.add((userId: userId, level: level, message: message));
  }
}
