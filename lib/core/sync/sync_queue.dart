import 'package:drift/drift.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/core/sync/sync_event.dart';
import 'package:uuid/uuid.dart';

/// Contrat minimal pour déposer un événement en file de synchronisation.
///
/// Extrait de [SyncQueue] au Module 3 pour que les services métier (ex.
/// `TourService`) dépendent de ce contrat plutôt que de l'implémentation
/// Drift concrète — même principe que les autres interfaces du projet
/// (`UserRepository`, `TourRepository`) : cela permet de fournir une
/// implémentation en mémoire dans les tests, sans dépendre de Drift.
///
/// [priority] a été ajouté au Module 6, en paramètre optionnel : tous les
/// appels existants (Modules 3, 4, 5) restent valides à l'identique et
/// utilisent implicitement [SyncPriority.normale].
abstract interface class SyncEventSink {
  Future<String> enqueue({
    required String eventType,
    required String payload,
    SyncPriority priority = SyncPriority.normale,
  });
}

/// Structure de la file d'attente d'événements en attente de
/// synchronisation (Offline First — voir Processus 7).
///
/// Module 1 : mécanique d'ajout et de lecture de la file. Module 6 : le
/// moteur réel de transmission est construit à côté, dans
/// `features/sync/domain/sync_service.dart`, qui consomme cette même
/// table via `SyncRepository` — cette classe reste le point d'entrée
/// UNIQUEMENT pour le dépôt d'événements par les modules métier.
class SyncQueue implements SyncEventSink {
  SyncQueue(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  /// Enregistre un nouvel événement en attente de synchronisation.
  ///
  /// [eventType] et [payload] sont volontairement génériques : chaque
  /// module métier définit ses propres types d'événements sans jamais
  /// modifier cette classe.
  @override
  Future<String> enqueue({
    required String eventType,
    required String payload,
    SyncPriority priority = SyncPriority.normale,
  }) async {
    final id = _uuid.v4();
    await _database
        .into(_database.syncEventsTable)
        .insert(
          SyncEventsTableCompanion.insert(
            id: id,
            eventType: eventType,
            payload: payload,
            createdAt: DateTime.now(),
            status: SyncEventStatus.pending,
            priority: Value(priority),
          ),
        );
    AppLogger.event(
      'Événement mis en file de synchronisation : $eventType',
      tag: 'SyncQueue',
    );
    return id;
  }

  /// Récupère les événements en attente, dans l'ordre chronologique de
  /// création. Conservé pour [SyncManager] (indicateur d'interface) ; le
  /// moteur du Module 6 utilise `SyncRepository.fetchOperationsToProcess`
  /// (priorité + ancienneté), plus complet.
  Future<List<SyncEventsTableData>> pendingEvents() {
    return (_database.select(_database.syncEventsTable)
          ..where((tbl) => tbl.status.equalsValue(SyncEventStatus.pending))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }
}
