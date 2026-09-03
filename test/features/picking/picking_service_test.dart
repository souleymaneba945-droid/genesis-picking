import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';
import 'package:genesis_picking/features/picking/domain/picking_service.dart';
import 'package:genesis_picking/features/tours/domain/tour_service.dart';

import '../../core/activity/fake_activity_log_sink.dart';
import '../tours/fake_sync_event_sink.dart';
import '../tours/fake_tour_remote_sink.dart';
import '../tours/fake_tour_remote_source.dart';
import '../tours/fake_tour_repository.dart';
import 'fake_picking_repository.dart';

const _tourId = 'tour-1';

List<PickingProduct> _threeProducts() => [
  const PickingProduct(
    id: 'p1',
    tourId: _tourId,
    ordre: 1,
    nom: 'Savon Kojie San',
    quantiteDemandee: 3,
    emplacement: 'Rayon A2',
    etat: ProductState.aRecuperer,
  ),
  const PickingProduct(
    id: 'p2',
    tourId: _tourId,
    ordre: 2,
    nom: 'Crème CeraVe',
    quantiteDemandee: 1,
    emplacement: 'Rayon B1',
    etat: ProductState.aRecuperer,
  ),
  const PickingProduct(
    id: 'p3',
    tourId: _tourId,
    ordre: 3,
    nom: 'Shampoing anti-chute',
    quantiteDemandee: 2,
    emplacement: 'Rayon C3',
    etat: ProductState.aRecuperer,
  ),
];

void main() {
  late FakeTourRepository tourRepository;
  late FakePickingRepository pickingRepository;
  late TourService tourService;
  late FakeActivityLogSink activityLogSink;
  late PickingService service;

  setUp(() async {
    tourRepository = FakeTourRepository();
    pickingRepository = FakePickingRepository(tourRepository);
    tourService = TourService(
      repository: tourRepository,
      remoteSource: FakeTourRemoteSource(),
      syncQueue: FakeSyncEventSink(),
      remoteSink: FakeTourRemoteSink(),
    );
    activityLogSink = FakeActivityLogSink();
    service = PickingService(
      pickingRepository: pickingRepository,
      tourRepository: tourRepository,
      tourService: tourService,
      activityLogSink: activityLogSink,
    );

    // Simule une tournée déjà téléchargée (Module 3), prête pour le
    // picking (Module 4).
    await tourRepository.saveDownloadedTour(
      tourId: _tourId,
      numeroTournee: 'T-2026-0001',
      preparateurId: 'prep-1',
      produits: const [], // le contenu détaillé vit dans PickingRepository
    );
    pickingRepository.seed(_tourId, _threeProducts());
    // Note : `saveDownloadedTour` a été appelé ci-dessus avec une liste de
    // produits vide côté Module 3 (le contenu détaillé est entièrement
    // géré par PickingRepository dans ce test) — cela ne fausse pas les
    // vérifications de progression ci-dessous, qui se basent toutes sur
    // les produits réellement chargés par PickingService, pas sur
    // `tour.nombreTotalProduits`.
  });

  group('PickingService.openSession — Chargement (Directive)', () {
    test('charge tous les produits, ordonnés, avec le premier comme courant', () async {
      final result = await service.openSession(_tourId);

      expect(result.isSuccess, isTrue);
      result.when(
        success: (session) {
          expect(session.produits.map((p) => p.id), ['p1', 'p2', 'p3']);
          expect(session.produitCourant?.id, 'p1');
          expect(session.progression.traites, 0);
          expect(session.progression.total, 3);
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('démarre la tournée (Téléchargée → En cours) à la première ouverture', () async {
      final result = await service.openSession(_tourId);
      result.when(
        success: (session) => expect(session.tour.statut.name, 'enCours'),
        failure: (_) => fail('devrait réussir'),
      );
    });
  });

  group('PickingService.validateCurrentProduct — Validation, états, produit suivant', () {
    test('quantité complète → état Collecté, avance au produit suivant', () async {
      await service.openSession(_tourId);

      final result = await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p1',
        etat: ProductState.collecte,
        quantiteCollectee: 3,
      );

      result.when(
        success: (session) {
          final p1 = session.produits.firstWhere((p) => p.id == 'p1');
          expect(p1.etat, ProductState.collecte);
          expect(p1.quantiteCollectee, 3);
          expect(session.produitCourant?.id, 'p2'); // produit suivant
          expect(session.progression.traites, 1);
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('quantité inférieure → état Partiellement collecté', () async {
      await service.openSession(_tourId);

      final result = await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p1',
        etat: ProductState.partiellementCollecte,
        quantiteCollectee: 1,
      );

      result.when(
        success: (session) {
          final p1 = session.produits.firstWhere((p) => p.id == 'p1');
          expect(p1.etat, ProductState.partiellementCollecte);
          expect(p1.quantiteCollectee, 1);
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('markCurrentProductIntrouvable → état Introuvable, avance quand même', () async {
      await service.openSession(_tourId);

      final result = await service.markCurrentProductIntrouvable(
        tourId: _tourId,
        productLineId: 'p1',
      );

      result.when(
        success: (session) {
          final p1 = session.produits.firstWhere((p) => p.id == 'p1');
          expect(p1.etat, ProductState.introuvable);
          expect(session.produitCourant?.id, 'p2');
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('après le dernier produit, produitCourant est nul (tournée prête à clôturer)', () async {
      await service.openSession(_tourId);
      await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p1',
        etat: ProductState.collecte,
        quantiteCollectee: 3,
      );
      await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p2',
        etat: ProductState.collecte,
        quantiteCollectee: 1,
      );
      final result = await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p3',
        etat: ProductState.introuvable,
      );

      result.when(
        success: (session) {
          expect(session.produitCourant, isNull);
          expect(session.estTerminee, isTrue);
          expect(session.progression.traites, 3);
        },
        failure: (_) => fail('devrait réussir'),
      );
    });
  });

  group('PickingService — Historique d\'activité', () {
    test('une validation dépose une entrée pour le préparateur de la tournée', () async {
      await service.openSession(_tourId);

      await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p1',
        etat: ProductState.collecte,
        quantiteCollectee: 3,
      );

      expect(activityLogSink.recorded, hasLength(1));
      final entree = activityLogSink.recorded.single;
      expect(entree.userId, 'prep-1'); // préparateurId de la tournée
      expect(entree.level, ActivityLevel.succes);
      expect(entree.message, contains('Savon Kojie San'));
    });

    test('un produit introuvable dépose une entrée de niveau avertissement', () async {
      await service.openSession(_tourId);

      await service.markCurrentProductIntrouvable(
        tourId: _tourId,
        productLineId: 'p1',
      );

      final entree = activityLogSink.recorded.single;
      expect(entree.level, ActivityLevel.avertissement);
      expect(entree.message, contains('introuvable'));
    });
  });

  group('PickingService — Progression et sauvegarde', () {
    test('la progression est persistée sur la tournée elle-même (pas seulement en mémoire)', () async {
      await service.openSession(_tourId);
      await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p1',
        etat: ProductState.collecte,
        quantiteCollectee: 3,
      );

      // On relit directement depuis le dépôt de tournées, indépendamment
      // de la session retournée — preuve que l'enregistrement est
      // effectif, pas seulement reflété dans l'objet en mémoire.
      final tour = await tourRepository.findById(_tourId);
      expect(tour!.produitsTraites, 1);
    });
  });

  group('PickingService — Reprise (Directive)', () {
    test('une réouverture après un produit déjà validé retrouve exactement l\'état', () async {
      await service.openSession(_tourId);
      await service.validateCurrentProduct(
        tourId: _tourId,
        productLineId: 'p1',
        etat: ProductState.collecte,
        quantiteCollectee: 3,
      );

      // Simule une fermeture puis une réouverture de l'application : on
      // rappelle openSession comme le ferait le Module 4 au redémarrage.
      final resumed = await service.openSession(_tourId);

      resumed.when(
        success: (session) {
          expect(session.produitCourant?.id, 'p2'); // pas p1, déjà traité
          expect(session.progression.traites, 1); // pas remis à zéro
          final p1 = session.produits.firstWhere((p) => p.id == 'p1');
          expect(p1.etat, ProductState.collecte); // état conservé
        },
        failure: (_) => fail('devrait réussir'),
      );
    });
  });

  // NOTE : la Directive ne demande de "produit précédent" que "si prévu".
  // Ce n'est PAS prévu ici : la Directive impose explicitement "aucun
  // retour manuel nécessaire" et "aucune validation intermédiaire" pour
  // la navigation. PickingService et PickingController n'exposent donc
  // volontairement aucune méthode de retour au produit précédent — un
  // produit déjà traité ne peut être corrigé qu'en repassant par
  // `validateCurrentProduct` avec un nouvel état, jamais en"reculant"
  // dans la séquence.
}
