import 'package:genesis_picking/features/sync/data/sync_operation.dart';
import 'package:genesis_picking/features/sync/data/sync_transport.dart';

/// Faux transport entièrement contrôlable, pour simuler des succès, des
/// échecs systématiques, des échecs sur certaines opérations seulement,
/// ou déclencher un effet de bord (ex. couper le réseau) au passage d'une
/// opération donnée.
class FakeSyncTransport implements SyncTransport {
  FakeSyncTransport({
    this.shouldFail = false,
    this.failingEventTypes = const {},
    this.onSend,
  });

  /// Si vrai, toute opération échoue.
  bool shouldFail;

  /// Types d'événements qui doivent échouer spécifiquement.
  Set<String> failingEventTypes;

  /// Effet de bord optionnel appelé avant chaque envoi (ex. couper le
  /// réseau après N appels) — voir `sync_service_test.dart`.
  void Function(SyncOperation operation)? onSend;

  final List<String> sentOperationIds = [];

  @override
  Future<SyncTransportResult> send(SyncOperation operation) async {
    onSend?.call(operation);
    sentOperationIds.add(operation.id);

    if (shouldFail || failingEventTypes.contains(operation.eventType)) {
      return const SyncTransportFailure('échec simulé');
    }
    return const SyncTransportSuccess();
  }
}
