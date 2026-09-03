import 'dart:async';

import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/sync/network_monitor.dart';
import 'package:genesis_picking/features/sync/data/sync_operation.dart';
import 'package:genesis_picking/features/sync/data/sync_repository.dart';
import 'package:genesis_picking/features/sync/data/sync_run_log.dart';
import 'package:genesis_picking/features/sync/data/sync_transport.dart';
/// Résumé d'une exécution de synchronisation, renvoyé par
/// [SyncService.synchronizeNow] pour l'écran (Directive : bouton
/// "Synchroniser maintenant").
class SyncRunSummary {
  const SyncRunSummary({
    required this.itemsProcessed,
    required this.itemsSucceeded,
    required this.itemsFailed,
    required this.skippedOffline,
  });

  final int itemsProcessed;
  final int itemsSucceeded;
  final int itemsFailed;

  /// Vrai si l'exécution n'a rien fait car l'appareil est hors ligne —
  /// jamais une erreur, conformément à "l'utilisateur ne doit jamais être
  /// bloqué par une absence de réseau".
  final bool skippedOffline;
}

/// Moteur de synchronisation — cœur du Module 6.
///
/// Responsabilité UNIQUE : faire progresser les opérations en attente
/// vers l'état "Synchronisé", dans l'ordre (priorité puis ancienneté),
/// sans jamais bloquer l'utilisateur ni perdre de donnée. Ne connaît ni
/// Drift, ni Riverpod, ni aucun détail d'affichage.
///
/// Ne modifie NI le moteur de picking NI le module coursier : il ne fait
/// que lire/transmettre les événements qu'ils ont déjà déposés dans la
/// file (via `SyncEventSink`, Module 1) et marquer leur progression.
class SyncService {
  SyncService({
    required SyncRepository repository,
    required SyncTransport transport,
    required ConnectivityState networkMonitor,
    int maxAttempts = 5,
  }) : _repository = repository,
       _transport = transport,
       _networkMonitor = networkMonitor,
       _maxAttempts = maxAttempts;

  final SyncRepository _repository;
  final SyncTransport _transport;
  final ConnectivityState _networkMonitor;
  final int _maxAttempts;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isRunning = false;

  /// À appeler une seule fois au démarrage : déclenche automatiquement
  /// une synchronisation dès le retour du réseau (Directive, "Détection
  /// réseau" — "détecter automatiquement le retour du réseau, lancer la
  /// synchronisation").
  void startAutoSync() {
    _connectivitySubscription = _networkMonitor.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) {
        AppLogger.info(
          'Réseau de retour — synchronisation automatique déclenchée',
          tag: 'SyncService',
        );
        unawaited(synchronizeNow());
      }
    });
  }

  /// Lance une synchronisation. Sûr à appeler à tout moment, y compris
  /// pendant que l'utilisateur continue de travailler (Directive :
  /// "L'utilisateur peut continuer à travailler pendant la
  /// synchronisation") — cette méthode ne verrouille jamais l'interface,
  /// elle ne fait que lire/écrire la base locale en arrière-plan.
  ///
  /// Protégée contre les exécutions concurrentes (bouton manuel + retour
  /// réseau automatique par exemple) par [_isRunning].
  Future<SyncRunSummary> synchronizeNow() async {
    if (_isRunning) {
      AppLogger.info(
        'Synchronisation déjà en cours, nouvelle demande ignorée',
        tag: 'SyncService',
      );
      return const SyncRunSummary(
        itemsProcessed: 0,
        itemsSucceeded: 0,
        itemsFailed: 0,
        skippedOffline: false,
      );
    }

    if (!_networkMonitor.isOnline) {
      AppLogger.info(
        'Hors connexion : synchronisation reportée, aucune donnée perdue',
        tag: 'SyncService',
      );
      return const SyncRunSummary(
        itemsProcessed: 0,
        itemsSucceeded: 0,
        itemsFailed: 0,
        skippedOffline: true,
      );
    }

    _isRunning = true;
    final runLogId = await _repository.startRunLog();
    final errors = <String>[];
    var succeeded = 0;
    var failed = 0;

    try {
      // Reprise : cette liste ne contient jamais les opérations déjà
      // "Synchronisé" — une exécution interrompue reprend donc
      // naturellement exactement là où elle s'était arrêtée, sans jamais
      // rejouer une opération déjà validée (Directive, "Reprise").
      final operations = await _repository.fetchOperationsToProcess();

      for (final operation in operations) {
        // Une coupure réseau en plein milieu de la boucle est détectée
        // ici : les opérations restantes ne sont simplement pas tentées
        // et resteront "En attente"/"À réessayer" pour la prochaine
        // exécution — pas d'erreur, pas de perte.
        if (!_networkMonitor.isOnline) {
          AppLogger.info(
            'Connexion perdue en cours de synchronisation, arrêt propre',
            tag: 'SyncService',
          );
          break;
        }

        final outcome = await _processOperation(operation);
        outcome.when(
          success: () => succeeded++,
          failure: (message) {
            failed++;
            errors.add('${operation.eventType}: $message');
          },
        );
      }
    } finally {
      _isRunning = false;
      await _repository.finishRunLog(
        runLogId: runLogId,
        itemsProcessed: succeeded + failed,
        itemsSucceeded: succeeded,
        itemsFailed: failed,
        errorSummary: errors.isEmpty ? null : errors.take(20).join(' | '),
      );
    }

    AppLogger.event(
      'Synchronisation terminée : $succeeded réussie(s), $failed échec(s)',
      tag: 'SyncService',
    );

    return SyncRunSummary(
      itemsProcessed: succeeded + failed,
      itemsSucceeded: succeeded,
      itemsFailed: failed,
      skippedOffline: false,
    );
  }

  /// Traite une opération individuelle. Ne lève jamais d'exception vers
  /// l'appelant : toute erreur est capturée et transformée en nouvel état
  /// de l'opération ("À réessayer" ou "Échec"), pour que la boucle
  /// principale continue même si certaines opérations échouent
  /// (Directive, "Détection réseau").
  Future<_OperationOutcome> _processOperation(SyncOperation operation) async {
    await _repository.markInProgress(operation.id);

    try {
      final result = await _transport.send(operation);

      switch (result) {
        case SyncTransportSuccess():
          await _repository.markSynced(operation.id);
          return const _OperationOutcome.success();

        case SyncTransportFailure(:final message):
          return _handleFailure(operation, message);
      }
    } catch (error) {
      return _handleFailure(operation, error.toString());
    }
  }

  Future<_OperationOutcome> _handleFailure(
    SyncOperation operation,
    String message,
  ) async {
    final attempts = operation.attemptCount + 1;

    if (attempts >= _maxAttempts) {
      await _repository.markFailed(
        operationId: operation.id,
        attemptCount: attempts,
        error: message,
      );
      AppLogger.error(
        'Opération ${operation.id} en échec définitif après $attempts tentatives',
        tag: 'SyncService',
      );
    } else {
      await _repository.markRetrying(
        operationId: operation.id,
        attemptCount: attempts,
        error: message,
      );
    }

    return _OperationOutcome.failure(message);
  }

  Future<int> pendingCount() => _repository.countPending();

  Future<SyncRunLog?> lastFinishedRun() => _repository.lastFinishedRun();

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

sealed class _OperationOutcome {
  const _OperationOutcome();

  const factory _OperationOutcome.success() = _OperationSuccess;
  const factory _OperationOutcome.failure(String message) = _OperationFailure;

  R when<R>({
    required R Function() success,
    required R Function(String message) failure,
  }) {
    return switch (this) {
      _OperationSuccess() => success(),
      _OperationFailure(:final message) => failure(message),
    };
  }
}

class _OperationSuccess extends _OperationOutcome {
  const _OperationSuccess();
}

class _OperationFailure extends _OperationOutcome {
  const _OperationFailure(this.message);
  final String message;
}
