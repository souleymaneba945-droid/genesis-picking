import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:genesis_picking/features/tours/domain/tour_service.dart';

import 'fake_sync_event_sink.dart';
import 'fake_tour_remote_sink.dart';
import 'fake_tour_remote_source.dart';
import 'fake_tour_repository.dart';

const _validPayload = TourDownloadPayload(
  tourId: 'tour-1',
  numeroTournee: 'T-2026-0001',
  preparateurId: 'prep-1',
  produits: [
    TourProductPayload(
      ordre: 1,
      nom: 'Savon Kojie San',
      quantiteDemandee: 3,
      emplacement: 'Rayon A2',
    ),
    TourProductPayload(
      ordre: 2,
      nom: 'Crème CeraVe',
      quantiteDemandee: 1,
      emplacement: 'Rayon B1',
    ),
  ],
);

void main() {
  late FakeTourRepository repository;
  late FakeTourRemoteSource remoteSource;
  late FakeSyncEventSink syncSink;
  late FakeTourRemoteSink remoteSink;
  late TourService service;

  setUp(() {
    repository = FakeTourRepository();
    remoteSource = FakeTourRemoteSource(tours: [_validPayload]);
    syncSink = FakeSyncEventSink();
    remoteSink = FakeTourRemoteSink();
    service = TourService(
      repository: repository,
      remoteSource: remoteSource,
      syncQueue: syncSink,
      remoteSink: remoteSink,
    );
  });

  group('TourService.downloadTour — Processus 2', () {
    test('télécharge et stocke une tournée valide', () async {
      final result = await service.downloadTour('tour-1');

      expect(result.isSuccess, isTrue);
      result.when(
        success: (tour) {
          expect(tour.statut, TourStatus.telechargee);
          expect(tour.nombreTotalProduits, 2);
          expect(tour.estTeleChargeeLocalement, isTrue);
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('dépose un événement de synchronisation après téléchargement',
        () async {
      await service.downloadTour('tour-1');
      expect(syncSink.enqueued, hasLength(1));
      expect(
        syncSink.enqueued.single.eventType,
        TourSyncEventTypes.tourneeTelechargee,
      );
    });

    test(
        'un second appel ne duplique pas et n\'appelle pas le réseau à nouveau',
        () async {
      final first = await service.downloadTour('tour-1');
      final second = await service.downloadTour('tour-1');

      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
      expect(repository.saveCallCount, 1);
      expect(remoteSource.fetchCallCount, 1);
    });

    test('échoue proprement en cas de coupure réseau', () async {
      remoteSource.networkErrorToThrow = Exception('pas de réseau');

      final result = await service.downloadTour('tour-1');

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('ne devrait pas réussir'),
        failure: (exception) => expect(exception, isA<NetworkException>()),
      );
      // Rien n'a été stocké, donc rien ne doit être marqué comme
      // téléchargé localement.
      expect(await repository.findById('tour-1'), isNull);
    });

    test('refuse une tournée sans aucun produit (intégrité)', () async {
      const emptyPayload = TourDownloadPayload(
        tourId: 'tour-vide',
        numeroTournee: 'T-2026-0099',
        preparateurId: 'prep-1',
        produits: [],
      );
      remoteSource.tours = [emptyPayload];

      final result = await service.downloadTour('tour-vide');

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('ne devrait pas réussir'),
        failure: (exception) => expect(exception, isA<ValidationException>()),
      );
    });

    test('refuse un produit avec une quantité invalide (intégrité)', () async {
      const invalidPayload = TourDownloadPayload(
        tourId: 'tour-invalide',
        numeroTournee: 'T-2026-0098',
        preparateurId: 'prep-1',
        produits: const [
          TourProductPayload(
            ordre: 1,
            nom: 'Produit sans quantité',
            quantiteDemandee: 0,
            emplacement: 'Rayon Z',
          ),
        ],
      );
      remoteSource.tours = [invalidPayload];

      final result = await service.downloadTour('tour-invalide');

      expect(result.isFailure, isTrue);
      expect(await repository.findById('tour-invalide'), isNull);
    });
  });

  group('TourService.startOrResume — Processus 3 (structurel)', () {
    test('refuse de démarrer une tournée non téléchargée', () async {
      await repository.registerAvailableTour(
        tourId: 'tour-1',
        numeroTournee: 'T-2026-0001',
        preparateurId: 'prep-1',
      );

      final result = await service.startOrResume('tour-1');

      expect(result.isFailure, isTrue);
    });

    test('passe de Téléchargée à En cours au premier démarrage', () async {
      await service.downloadTour('tour-1');
      final result = await service.startOrResume('tour-1');

      expect(result.isSuccess, isTrue);
      result.when(
        success: (tour) => expect(tour.statut, TourStatus.enCours),
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('une tournée déjà en cours est reprise sans être réinitialisée',
        () async {
      await service.downloadTour('tour-1');
      await service.startOrResume('tour-1'); // Téléchargée → En cours
      await repository.updateStatus(
        tourId: 'tour-1',
        statut: TourStatus.enCours,
      );

      // Simule une progression déjà enregistrée par le Module 4.
      final beforeResume = await repository.findById('tour-1');
      expect(beforeResume!.statut, TourStatus.enCours);

      final result = await service.startOrResume('tour-1');

      result.when(
        success: (tour) {
          expect(tour.statut, TourStatus.enCours);
          // La progression n'a pas été modifiée par la reprise.
          expect(tour.produitsTraites, beforeResume.produitsTraites);
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('refuse de reprendre une tournée déjà terminée', () async {
      await service.downloadTour('tour-1');
      await repository.updateStatus(
        tourId: 'tour-1',
        statut: TourStatus.terminee,
      );

      final result = await service.startOrResume('tour-1');
      expect(result.isFailure, isTrue);
    });
  });

  group('TourService.completeTour — garde-fou structurel', () {
    test('refuse la clôture si tous les produits n\'ont pas d\'état final',
        () async {
      await service.downloadTour('tour-1'); // 2 produits, 0 traités

      final result = await service.completeTour('tour-1');

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('ne devrait pas réussir'),
        failure: (exception) => expect(exception, isA<ValidationException>()),
      );
    });
  });

  group('TourService.deleteTour — correction d\'un import erroné', () {
    test('supprime la tournée localement et sur le serveur', () async {
      await service.downloadTour('tour-1');

      final result = await service.deleteTour('tour-1');

      expect(result.isSuccess, isTrue);
      expect(await repository.findById('tour-1'), isNull);
      expect(remoteSink.deleted, contains('tour-1'));
    });

    test('échoue proprement si la tournée n\'existe pas', () async {
      final result = await service.deleteTour('inconnue');
      expect(result.isFailure, isTrue);
    });
  });

  group('TourService.watchTours — synchronisation en direct', () {
    Future<void> attendreEvenement(List<Object?> events, int minimum) {
      return Future.doWhile(() async {
        if (events.length >= minimum) return false;
        await Future.delayed(const Duration(milliseconds: 5));
        return true;
      });
    }

    test(
        'émet la liste locale immédiatement, puis une liste à jour dès '
        'qu\'une tournée arrive côté serveur', () async {
      await repository.saveDownloadedTour(
        tourId: 'tour-1',
        numeroTournee: 'T-2026-0001',
        preparateurId: 'prep-1',
        produits: const [
          TourProductPayload(
            ordre: 1,
            nom: 'Produit A',
            quantiteDemandee: 1,
            emplacement: 'A1',
          ),
        ],
      );

      final events = <List<String>>[];
      final sub = service
          .watchTours('prep-1')
          .listen((tours) => events.add(tours.map((t) => t.id).toList()));

      await attendreEvenement(events, 1);
      expect(events.single, ['tour-1']);

      remoteSource.emitAvailableTours([
        (tourId: 'tour-2', numeroTournee: 'T-2026-0002'),
      ]);

      await attendreEvenement(events, 2);
      expect(events.last, containsAll(['tour-1', 'tour-2']));

      await sub.cancel();
    });

    test(
        'une panne du flux distant n\'interrompt jamais le flux — les '
        'données locales déjà connues restent affichées', () async {
      await repository.saveDownloadedTour(
        tourId: 'tour-1',
        numeroTournee: 'T-2026-0001',
        preparateurId: 'prep-1',
        produits: const [
          TourProductPayload(
            ordre: 1,
            nom: 'Produit A',
            quantiteDemandee: 1,
            emplacement: 'A1',
          ),
        ],
      );

      final events = <List<String>>[];
      var erreurRecue = false;
      var fluxFerme = false;
      final sub = service.watchTours('prep-1').listen(
            (tours) => events.add(tours.map((t) => t.id).toList()),
            onError: (_) => erreurRecue = true,
            onDone: () => fluxFerme = true,
          );

      await attendreEvenement(events, 1);
      expect(events.single, ['tour-1']);

      remoteSource.emitWatchError(Exception('panne réseau simulée'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(erreurRecue, isFalse);
      expect(fluxFerme, isFalse);
      expect(events, hasLength(1));

      await sub.cancel();
    });
  });
}
