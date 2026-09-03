import 'package:genesis_picking/features/sync/data/sync_operation.dart';
import 'package:genesis_picking/features/sync/data/sync_run_log.dart';

/// Contrat abstrait d'accès aux données de synchronisation.
///
/// Distinct de `SyncQueue` (Module 1, point d'entrée pour DÉPOSER un
/// événement) : `SyncRepository` est l'accès aux données utilisé par le
/// moteur lui-même (`SyncService`) pour lire, faire progresser et
/// journaliser les opérations — responsabilité unique et séparée
/// (Directive Module 6).
abstract interface class SyncRepository {
  /// Opérations à traiter (En attente + À réessayer), triées par
  /// priorité décroissante puis ancienneté croissante — l'ordre exact
  /// dans lequel `SyncService` doit les transmettre.
  Future<List<SyncOperation>> fetchOperationsToProcess();

  /// Nombre d'opérations non encore synchronisées (Directive, écran :
  /// "nombre d'éléments en attente").
  Future<int> countPending();

  Future<SyncOperation?> findById(String operationId);

  Future<void> markInProgress(String operationId);
  Future<void> markSynced(String operationId);

  Future<void> markRetrying({
    required String operationId,
    required int attemptCount,
    required String error,
  });

  Future<void> markFailed({
    required String operationId,
    required int attemptCount,
    required String error,
  });

  /// Ouvre une nouvelle ligne de journal ("début" — Directive, "Journal")
  /// et renvoie son identifiant.
  Future<String> startRunLog();

  /// Clôture une ligne de journal ("fin", nombre d'éléments, erreurs).
  Future<void> finishRunLog({
    required String runLogId,
    required int itemsProcessed,
    required int itemsSucceeded,
    required int itemsFailed,
    String? errorSummary,
  });

  /// Dernière exécution terminée (Directive, écran : "dernière
  /// synchronisation").
  Future<SyncRunLog?> lastFinishedRun();
}
