import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/sync/sync_event.dart';
import 'package:genesis_picking/features/sync/data/sync_operation.dart';
import 'package:genesis_picking/features/sync/domain/sync_service.dart';

import 'fake_connectivity_state.dart';
import 'fake_sync_repository.dart';
import 'fake_sync_transport.dart';

SyncOperation _operation(
  String id, {
  DateTime? createdAt,
  SyncPriority priority = SyncPriority.normale,
  int attemptCount = 0,
  SyncEventStatus status = SyncEventStatus.pending,
}) {
  return SyncOperation(
    id: id,
    eventType: 'evenement_test',
    payload: '{}',
    createdAt: createdAt ?? DateTime.now(),
    status: status,
    attemptCount: attemptCount,
    priority: priority,
  );
}

void main() {
  late FakeSyncRepository repository;
  late FakeConnectivityState connectivity;

  setUp(() {
    repository = FakeSyncRepository();
    connectivity = FakeConnectivityState(isOnline: true);
  });

  group('SyncService.synchronizeNow — synchronisation sans erreur', () {
    test('toutes les opérations en attente sont marquées synchronisées', () async {
      repository.seed(_operation('op-1'));
      repository.seed(_operation('op-2'));
      final transport = FakeSyncTransport();
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      final summary = await service.synchronizeNow();

      expect(summary.itemsSucceeded, 2);
      expect(summary.itemsFailed, 0);
      expect(await repository.countPending(), 0);
      expect(
        repository.all.every((op) => op.status == SyncEventStatus.synced),
        isTrue,
      );
    });

    test('ne fait rien hors connexion, sans erreur ni perte', () async {
      connectivity.setOnline(false);
      repository.seed(_operation('op-1'));
      final transport = FakeSyncTransport();
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      final summary = await service.synchronizeNow();

      expect(summary.skippedOffline, isTrue);
      expect(transport.sentOperationIds, isEmpty);
      expect(await repository.countPending(), 1); // rien perdu
    });

    test('respecte l\'ordre de priorité (haute avant normale avant basse)', () async {
      repository.seed(
        _operation(
          'basse',
          priority: SyncPriority.basse,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      repository.seed(
        _operation(
          'haute',
          priority: SyncPriority.haute,
          createdAt: DateTime(2026, 1, 2),
        ),
      );
      repository.seed(
        _operation(
          'normale',
          priority: SyncPriority.normale,
          createdAt: DateTime(2026, 1, 3),
        ),
      );
      final transport = FakeSyncTransport();
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      await service.synchronizeNow();

      expect(transport.sentOperationIds, ['haute', 'normale', 'basse']);
    });
  });

  group('SyncService — Coupure réseau pendant la synchronisation', () {
    test('les opérations restantes ne sont pas perdues, juste non traitées', () async {
      repository.seed(_operation('op-1', createdAt: DateTime(2026, 1, 1)));
      repository.seed(_operation('op-2', createdAt: DateTime(2026, 1, 2)));
      repository.seed(_operation('op-3', createdAt: DateTime(2026, 1, 3)));

      final transport = FakeSyncTransport(
        onSend: (operation) {
          if (operation.id == 'op-2') {
            connectivity.setOnline(false); // coupure pendant le traitement
          }
        },
      );
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      final summary = await service.synchronizeNow();

      // op-1 traité, op-2 traité (la coupure survient APRES son envoi),
      // op-3 jamais tenté car la boucle vérifie la connexion avant.
      expect(summary.itemsSucceeded, 2);
      expect(transport.sentOperationIds, ['op-1', 'op-2']);
      final op3 = await repository.findById('op-3');
      expect(op3!.status, SyncEventStatus.pending); // rien perdu
    });
  });

  group('SyncService — Reprise', () {
    test('une seconde exécution ne rejoue jamais les opérations déjà synchronisées', () async {
      repository.seed(_operation('op-1', createdAt: DateTime(2026, 1, 1)));
      repository.seed(_operation('op-2', createdAt: DateTime(2026, 1, 2)));

      final transport = FakeSyncTransport(
        onSend: (operation) {
          // La coupure doit survenir PENDANT le traitement de op-1 pour que
          // la boucle s'arrête avant de tenter op-2 (elle vérifie la
          // connexion au début de chaque itération suivante — voir
          // SyncService.synchronizeNow) : couper au passage de op-2 lui-même
          // arriverait trop tard, comme le montre le test "Coupure réseau"
          // ci-dessus où op-2 est déjà envoyé quand la coupure survient.
          if (operation.id == 'op-1') connectivity.setOnline(false);
        },
      );
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      await service.synchronizeNow(); // interrompue après op-1
      expect(transport.sentOperationIds, ['op-1']);

      connectivity.setOnline(true);
      transport.onSend = null; // plus de coupure programmée
      await service.synchronizeNow(); // reprise

      // op-1 n'est jamais renvoyé une seconde fois.
      expect(transport.sentOperationIds, ['op-1', 'op-2']);
      expect(await repository.countPending(), 0);
    });
  });

  group('SyncService — Doublons', () {
    test('deux appels concurrents ne traitent chaque opération qu\'une fois', () async {
      repository.seed(_operation('op-1'));
      final transport = FakeSyncTransport();
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      // Lancées "en même temps" (sans attendre la première).
      final future1 = service.synchronizeNow();
      final future2 = service.synchronizeNow();
      await Future.wait([future1, future2]);

      expect(transport.sentOperationIds.where((id) => id == 'op-1').length, 1);
    });
  });

  group('SyncService — Échecs et nouvelle tentative', () {
    test('un échec passe l\'opération à "À réessayer" tant que le maximum n\'est pas atteint', () async {
      repository.seed(_operation('op-1'));
      final transport = FakeSyncTransport(shouldFail: true);
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
        maxAttempts: 5,
      );

      await service.synchronizeNow();

      final op = await repository.findById('op-1');
      expect(op!.status, SyncEventStatus.retrying);
      expect(op.attemptCount, 1);
    });

    test('l\'opération passe à "Échec" définitif une fois le maximum atteint', () async {
      repository.seed(_operation('op-1', attemptCount: 4));
      final transport = FakeSyncTransport(shouldFail: true);
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
        maxAttempts: 5,
      );

      await service.synchronizeNow();

      final op = await repository.findById('op-1');
      expect(op!.status, SyncEventStatus.failed);
    });

    test('une opération en échec n\'empêche pas les suivantes d\'être traitées', () async {
      repository.seed(_operation('op-1', createdAt: DateTime(2026, 1, 1)));
      repository.seed(_operation('op-2', createdAt: DateTime(2026, 1, 2)));
      final transport = FakeSyncTransport(failingEventTypes: {'evenement_test'});
      // op-1 et op-2 partagent le même eventType : les deux échouent, mais
      // les deux doivent être TENTÉES malgré l'échec de la première.
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      await service.synchronizeNow();

      expect(transport.sentOperationIds, ['op-1', 'op-2']);
    });
  });

  group('SyncService — Charge (plusieurs centaines d\'opérations)', () {
    test('traite correctement 300 opérations en attente', () async {
      for (var i = 0; i < 300; i++) {
        repository.seed(
          _operation('op-$i', createdAt: DateTime(2026, 1, 1, 0, i)),
        );
      }
      final transport = FakeSyncTransport();
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      final summary = await service.synchronizeNow();

      expect(summary.itemsSucceeded, 300);
      expect(await repository.countPending(), 0);
    });
  });

  group('SyncService — Après plusieurs jours hors connexion', () {
    test('les opérations accumulées sont toutes transmises au retour du réseau', () async {
      connectivity.setOnline(false);
      final ancienneDate = DateTime.now().subtract(const Duration(days: 4));
      for (var i = 0; i < 10; i++) {
        repository.seed(
          _operation(
            'op-$i',
            createdAt: ancienneDate.add(Duration(minutes: i)),
          ),
        );
      }
      final transport = FakeSyncTransport();
      final service = SyncService(
        repository: repository,
        transport: transport,
        networkMonitor: connectivity,
      );

      // Plusieurs tentatives infructueuses pendant la coupure prolongée.
      await service.synchronizeNow();
      await service.synchronizeNow();
      expect(await repository.countPending(), 10); // rien perdu, rien tenté

      connectivity.setOnline(true);
      final summary = await service.synchronizeNow();

      expect(summary.itemsSucceeded, 10);
      expect(await repository.countPending(), 0);
    });
  });
}
