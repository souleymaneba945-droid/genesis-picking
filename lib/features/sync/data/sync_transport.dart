import 'package:genesis_picking/features/sync/data/sync_operation.dart';

/// Résultat de la transmission d'une opération vers le serveur.
sealed class SyncTransportResult {
  const SyncTransportResult();
}

class SyncTransportSuccess extends SyncTransportResult {
  const SyncTransportSuccess();
}

class SyncTransportFailure extends SyncTransportResult {
  const SyncTransportFailure(this.message);
  final String message;
}

/// Transport chargé de transmettre une opération à un serveur distant.
///
/// AUCUN backend réel n'existe encore dans ce projet (même principe que
/// `NoTourRemoteSource`, module Import). `SyncService` ne
/// dépend que de cette interface, jamais d'une implémentation concrète —
/// brancher un vrai serveur revient à fournir une nouvelle implémentation
/// ici, sans toucher au reste du moteur de synchronisation.
abstract interface class SyncTransport {
  Future<SyncTransportResult> send(SyncOperation operation);
}

/// Implémentation de DÉMONSTRATION : simule un serveur qui accepte
/// toujours la transmission, avec une latence minime réaliste.
///
/// Permet de tester le moteur de synchronisation de bout en bout
/// (file, priorités, reprise, journal) sans dépendre d'un vrai serveur.
/// Les tests unitaires du moteur, eux, utilisent une implémentation
/// entièrement contrôlable (`FakeSyncTransport`) pour simuler des échecs.
class SimulatedSyncTransport implements SyncTransport {
  @override
  Future<SyncTransportResult> send(SyncOperation operation) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return const SyncTransportSuccess();
  }
}
