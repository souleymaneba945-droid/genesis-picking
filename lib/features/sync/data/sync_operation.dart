import 'package:genesis_picking/core/sync/sync_event.dart';

/// Une opération en file de synchronisation, telle que manipulée par le
/// moteur du Module 6.
///
/// Enveloppe les mêmes données que la ligne Drift sous-jacente
/// (`SyncEventsTableData`), pour que le reste du module (service,
/// résolveur de conflits, écran) ne dépende jamais de Drift directement.
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.eventType,
    required this.payload,
    required this.createdAt,
    required this.status,
    required this.attemptCount,
    required this.priority,
    this.lastAttemptAt,
    this.lastError,
  });

  final String id;
  final String eventType;
  final String payload;
  final DateTime createdAt;
  final SyncEventStatus status;
  final int attemptCount;
  final SyncPriority priority;
  final DateTime? lastAttemptAt;
  final String? lastError;

  SyncOperation copyWith({
    SyncEventStatus? status,
    int? attemptCount,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return SyncOperation(
      id: id,
      eventType: eventType,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      priority: priority,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Libellés français exacts de la Directive Module 6, pour l'affichage
/// uniquement — les valeurs internes de [SyncEventStatus] restent celles
/// posées au Module 1 (voir `core/sync/sync_event.dart`).
extension SyncEventStatusLabel on SyncEventStatus {
  String get libelleFrancais => switch (this) {
    SyncEventStatus.pending => 'En attente',
    SyncEventStatus.inProgress => 'En cours',
    SyncEventStatus.synced => 'Synchronisé',
    SyncEventStatus.failed => 'Échec',
    SyncEventStatus.retrying => 'À réessayer',
  };
}
