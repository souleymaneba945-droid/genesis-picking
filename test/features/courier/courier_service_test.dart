import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/courier/domain/courier_service.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

import '../../core/activity/fake_activity_log_sink.dart';
import '../auth/fake_user_repository.dart';
import '../tours/fake_sync_event_sink.dart';
import 'fake_availability_checker.dart';
import 'fake_courier_repository.dart';
import 'fake_courier_request_remote_sink.dart';
import 'fake_courier_request_remote_source.dart';
import 'fake_product_repository.dart';

const _tourId = 'tour-1';
const _productLineId = 'p1';
const _preparateurId = 'prep-1';

void main() {
  late FakeCourierRepository courierRepository;
  late FakeUserRepository userRepository;
  late FakeProductRepository productRepository;
  late FakeCourierAvailabilityChecker availabilityChecker;
  late FakeSyncEventSink syncSink;
  late FakeActivityLogSink activityLogSink;
  late FakeCourierRequestRemoteSink remoteSink;
  late FakeCourierRequestRemoteSource remoteSource;
  late CourierService service;

  setUp(() async {
    courierRepository = FakeCourierRepository();
    userRepository = FakeUserRepository();
    productRepository = FakeProductRepository();
    availabilityChecker = FakeCourierAvailabilityChecker(isOnline: true);
    syncSink = FakeSyncEventSink();
    activityLogSink = FakeActivityLogSink();
    remoteSink = FakeCourierRequestRemoteSink();
    remoteSource = FakeCourierRequestRemoteSource();

    service = CourierService(
      courierRepository: courierRepository,
      userRepository: userRepository,
      productRepository: productRepository,
      availabilityChecker: availabilityChecker,
      syncQueue: syncSink,
      activityLogSink: activityLogSink,
      remoteSink: remoteSink,
      remoteSource: remoteSource,
    );

    await userRepository.create(
      identifiant: 'coursier1',
      nomAffichage: 'Moussa',
      role: UserRole.coursier,
      motDePasse: 'MotDePasse123',
    );
    await userRepository.create(
      identifiant: 'prep1',
      nomAffichage: 'Amadou',
      role: UserRole.preparateur,
      motDePasse: 'MotDePasse123',
    );
    productRepository.seed(
      const PickingProduct(
        id: _productLineId,
        tourId: _tourId,
        ordre: 1,
        nom: 'Savon Kojie San',
        description: 'SKU-4821 - 3401590123456',
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
        etat: ProductState.introuvable,
        imageUrl: 'https://cdn.example.com/kojie-san.jpg',
      ),
    );
  });

  Future<String> coursierId0() async {
    final account = await userRepository.findByIdentifiant('coursier1');
    return account!.id;
  }

  Future<String> preparateurAccountId() async {
    final account = await userRepository.findByIdentifiant('prep1');
    return account!.id;
  }

  group('CourierService.listActiveCouriers — Choix du coursier', () {
    test('ne renvoie que les coursiers actifs, avec leur charge ouverte',
        () async {
      final coursierId = await coursierId0();
      final summaries = await service.listActiveCouriers();

      expect(summaries, hasLength(1));
      expect(summaries.single.id, coursierId);
      expect(summaries.single.nom, 'Moussa');
      expect(summaries.single.demandesEnAttente, 0);
    });

    test('un coursier désactivé n\'apparaît plus dans la liste', () async {
      final coursierId = await coursierId0();
      await userRepository.setActive(userId: coursierId, actif: false);

      final summaries = await service.listActiveCouriers();
      expect(summaries, isEmpty);
    });

    test('la charge ouverte augmente après une nouvelle demande', () async {
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      final summaries = await service.listActiveCouriers();
      expect(summaries.single.demandesEnAttente, 1);
    });
  });

  group('CourierService.createRequest — Création d\'une demande', () {
    test('crée une demande avec tous les champs requis', () async {
      final coursierId = await coursierId0();
      final result = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      result.when(
        success: (request) {
          expect(request.preparateurId, _preparateurId);
          expect(request.coursierId, coursierId);
          expect(request.tourId, _tourId);
          expect(request.productLineId, _productLineId);
          expect(request.quantiteDemandee, 3);
          expect(request.emplacement, 'Rayon A2');
          expect(request.dateCreation, isNotNull);
          // Instantané produit pris dès la création (voir
          // `CourierRequestsTable`) — indispensable pour que l'appareil du
          // coursier, qui n'a jamais téléchargé cette tournée, puisse
          // quand même afficher nom/description/photo.
          expect(request.produitNom, 'Savon Kojie San');
          expect(request.produitDescription, 'SKU-4821 - 3401590123456');
          expect(
            request.produitImageUrl,
            'https://cdn.example.com/kojie-san.jpg',
          );
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('dépose un événement de synchronisation', () async {
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      expect(syncSink.enqueued, hasLength(1));
      expect(
        syncSink.enqueued.single.eventType,
        CourierSyncEventTypes.demandeCreee,
      );
    });
  });

  group('CourierService — Fonctionnement hors connexion', () {
    test('une demande créée hors connexion passe à "En attente"', () async {
      availabilityChecker.setOnline(false);
      final coursierId = await coursierId0();

      final result = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      result.when(
        success: (request) =>
            expect(request.etat, CourierRequestStatus.enAttente),
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('une demande créée en ligne passe directement à "Reçue"', () async {
      availabilityChecker.setOnline(true);
      final coursierId = await coursierId0();

      final result = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      result.when(
        success: (request) => expect(request.etat, CourierRequestStatus.recue),
        failure: (_) => fail('devrait réussir'),
      );
    });

    test(
        'synchronisation ultérieure : "En attente" devient "Reçue" au retour du réseau',
        () async {
      availabilityChecker.setOnline(false);
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      // Le réseau revient : le coursier ouvre son écran "Mes demandes".
      availabilityChecker.setOnline(true);
      final requests = await service.listRequestsForCoursier(coursierId);

      expect(requests, hasLength(1));
      expect(requests.single.etat, CourierRequestStatus.recue);
    });
  });

  group(
    'CourierService.listRequestsForCoursierWithPreparateur — regroupement',
    () {
      test(
        'chaque demande est accompagnée du nom réel du préparateur qui '
        'l\'a envoyée',
        () async {
          final coursierId = await coursierId0();
          final preparateurId = await preparateurAccountId();
          await service.createRequest(
            preparateurId: preparateurId,
            coursierId: coursierId,
            tourId: _tourId,
            productLineId: _productLineId,
            quantiteDemandee: 3,
            emplacement: 'Rayon A2',
          );

          final enrichies = await service
              .listRequestsForCoursierWithPreparateur(coursierId);

          expect(enrichies, hasLength(1));
          expect(enrichies.single.preparateurNom, 'Amadou');
          expect(enrichies.single.request.preparateurId, preparateurId);
        },
      );

      test(
        'chaque demande est accompagnée du nom et de la photo du produit '
        '— même image que l\'écran de picking, jamais une liste sans '
        'photo',
        () async {
          final coursierId = await coursierId0();
          await service.createRequest(
            preparateurId: _preparateurId,
            coursierId: coursierId,
            tourId: _tourId,
            productLineId: _productLineId,
            quantiteDemandee: 3,
            emplacement: 'Rayon A2',
          );

          final enrichies = await service
              .listRequestsForCoursierWithPreparateur(coursierId);

          expect(enrichies.single.produitNom, 'Savon Kojie San');
          expect(
            enrichies.single.produitDescription,
            'SKU-4821 - 3401590123456',
          );
          expect(
            enrichies.single.produitImageUrl,
            'https://cdn.example.com/kojie-san.jpg',
          );
        },
      );

      test(
        'un identifiant préparateur inconnu retombe sur un libellé par '
        'défaut, jamais une erreur',
        () async {
          final coursierId = await coursierId0();
          // _preparateurId ('prep-1') ne correspond à aucun compte réel.
          await service.createRequest(
            preparateurId: _preparateurId,
            coursierId: coursierId,
            tourId: _tourId,
            productLineId: _productLineId,
            quantiteDemandee: 3,
            emplacement: 'Rayon A2',
          );

          final enrichies = await service
              .listRequestsForCoursierWithPreparateur(coursierId);

          expect(enrichies.single.preparateurNom, 'Préparateur');
        },
      );

      test('aucune demande → liste vide, sans requête inutile', () async {
        final coursierId = await coursierId0();
        final enrichies =
            await service.listRequestsForCoursierWithPreparateur(coursierId);
        expect(enrichies, isEmpty);
      });
    },
  );

  group('CourierService.openRequest / respond — Réception, validation', () {
    test('ouvrir une demande "Reçue" la fait passer à "Acceptée"', () async {
      final coursierId = await coursierId0();
      final preparateurId = await preparateurAccountId();
      final created = await service.createRequest(
        preparateurId: preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      final detail = await service.openRequest(requestId);
      detail.when(
        success: (view) {
          expect(view.request.etat, CourierRequestStatus.acceptee);
          expect(view.produitNom, 'Savon Kojie San');
          expect(view.produitDescription, 'SKU-4821 - 3401590123456');
          expect(view.preparateurNom, 'Amadou');
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('répondre "Produit retrouvé" fait passer la demande à "Traitée"',
        () async {
      final coursierId = await coursierId0();
      final created = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      await service.openRequest(requestId); // Acceptée
      final result = await service.respond(
        requestId: requestId,
        resultat: CourierRequestResult.retrouve,
      );

      result.when(
        success: (request) {
          expect(request.etat, CourierRequestStatus.traitee);
          expect(request.resultat, CourierRequestResult.retrouve);
          expect(request.dateTraitement, isNotNull);
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('refuse de répondre à une demande non encore acceptée', () async {
      final coursierId = await coursierId0();
      final created = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      // Pas d'appel à openRequest ici : la demande reste "Reçue".
      final result = await service.respond(
        requestId: requestId,
        resultat: CourierRequestResult.retrouve,
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('CourierService — Historique d\'activité', () {
    test('répondre "retrouvé" dépose une entrée de succès pour le coursier',
        () async {
      final coursierId = await coursierId0();
      final created = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      await service.openRequest(requestId);
      await service.respond(
        requestId: requestId,
        resultat: CourierRequestResult.retrouve,
      );

      final entree = activityLogSink.recorded.single;
      expect(entree.userId, coursierId);
      expect(entree.level, ActivityLevel.succes);
      expect(entree.message, contains('Savon Kojie San'));
    });

    test('répondre "non retrouvé" dépose une entrée d\'avertissement',
        () async {
      final coursierId = await coursierId0();
      final created = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      await service.openRequest(requestId);
      await service.respond(
        requestId: requestId,
        resultat: CourierRequestResult.nonRetrouve,
      );

      final entree = activityLogSink.recorded.single;
      expect(entree.level, ActivityLevel.avertissement);
    });
  });

  group('CourierService — Synchronisation réelle (Firestore)', () {
    test('createRequest transmet la demande créée au serveur', () async {
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      expect(remoteSink.pushed, hasLength(1));
      expect(remoteSink.pushed.single.coursierId, coursierId);
    });

    test('respond transmet la demande mise à jour au serveur', () async {
      final coursierId = await coursierId0();
      final created = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      await service.openRequest(requestId);
      await service.respond(
        requestId: requestId,
        resultat: CourierRequestResult.retrouve,
      );

      // createRequest, openRequest (transition "Acceptée") et respond
      // transmettent chacun leur propre mise à jour d'état.
      expect(remoteSink.pushed, hasLength(3));
      expect(remoteSink.pushed.last.etat, CourierRequestStatus.traitee);
    });

    test(
        'listRequestsForCoursier récupère une demande créée par un '
        'préparateur sur un AUTRE appareil', () async {
      final coursierId = await coursierId0();
      remoteSource.remoteRequests.add(
        CourierRequest(
          id: 'depuis-un-autre-appareil',
          preparateurId: _preparateurId,
          coursierId: coursierId,
          tourId: _tourId,
          productLineId: _productLineId,
          quantiteDemandee: 2,
          emplacement: 'Rayon B3',
          dateCreation: DateTime.now(),
          etat: CourierRequestStatus.recue,
        ),
      );

      final requests = await service.listRequestsForCoursier(coursierId);

      expect(
        requests.any((r) => r.id == 'depuis-un-autre-appareil'),
        isTrue,
      );
      // La demande découverte à distance doit aussi être acquise
      // localement (visible même hors-ligne au prochain démarrage).
      expect(
        await courierRepository.findById('depuis-un-autre-appareil'),
        isNotNull,
      );
    });

    test(
        'une demande reçue à distance affiche quand même le nom/la photo '
        'du produit même si ce produit n\'existe pas localement — cas du '
        'coursier qui n\'a jamais téléchargé cette tournée', () async {
      final coursierId = await coursierId0();
      remoteSource.remoteRequests.add(
        CourierRequest(
          id: 'depuis-un-autre-appareil-sans-produit-local',
          preparateurId: _preparateurId,
          coursierId: coursierId,
          tourId: _tourId,
          productLineId: 'produit-jamais-telecharge-ici',
          quantiteDemandee: 2,
          emplacement: 'Rayon B3',
          dateCreation: DateTime.now(),
          etat: CourierRequestStatus.recue,
          produitNom: 'Doliprane 1000mg',
          produitDescription: 'SKU-9012 - 3401590654321',
          produitImageUrl: 'data:image/jpeg;base64,ZmFrZQ==',
        ),
      );

      final enrichies =
          await service.listRequestsForCoursierWithPreparateur(coursierId);

      final recue = enrichies.singleWhere(
        (e) => e.request.id == 'depuis-un-autre-appareil-sans-produit-local',
      );
      expect(recue.produitNom, 'Doliprane 1000mg');
      expect(recue.produitDescription, 'SKU-9012 - 3401590654321');
      expect(recue.produitImageUrl, 'data:image/jpeg;base64,ZmFrZQ==');
    });

    test(
        'une panne réseau au moment du pull n\'empêche pas de voir les '
        'demandes déjà connues localement', () async {
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      remoteSource.pannePersistante = true;

      final requests = await service.listRequestsForCoursier(coursierId);
      expect(requests, hasLength(1));
    });
  });

  group('CourierService.listRequestsForPreparateur — Retour préparateur', () {
    test(
        'une demande "Traitée" devient "Terminée" dès consultation par le préparateur',
        () async {
      final coursierId = await coursierId0();
      final preparateurId = await preparateurAccountId();
      final created = await service.createRequest(
        preparateurId: preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );
      await service.openRequest(requestId);
      await service.respond(
        requestId: requestId,
        resultat: CourierRequestResult.nonRetrouve,
      );

      final requests = await service.listRequestsForPreparateur(preparateurId);

      expect(requests, hasLength(1));
      expect(requests.single.etat, CourierRequestStatus.terminee);
      expect(requests.single.resultat, CourierRequestResult.nonRetrouve);
      expect(requests.single.dateCloture, isNotNull);
    });
  });

  group('CourierService — Reprise après fermeture', () {
    test('les demandes existent toujours dans le dépôt après une "réouverture"',
        () async {
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      // Simule une fermeture puis réouverture de l'application : un
      // nouveau CourierService est reconstruit sur le MÊME dépôt (qui
      // représente la base locale persistante).
      final serviceApresReouverture = CourierService(
        courierRepository: courierRepository,
        userRepository: userRepository,
        productRepository: productRepository,
        availabilityChecker: availabilityChecker,
        syncQueue: syncSink,
        activityLogSink: activityLogSink,
        remoteSink: remoteSink,
        remoteSource: remoteSource,
      );

      final requests = await serviceApresReouverture.listRequestsForCoursier(
        coursierId,
      );
      expect(requests, hasLength(1));
    });
  });

  group('CourierService.deleteRequest — correction d\'une erreur d\'envoi', () {
    test('supprime la demande localement et sur le serveur', () async {
      final coursierId = await coursierId0();
      final created = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final requestId = created.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      final result = await service.deleteRequest(requestId);

      expect(result.isSuccess, isTrue);
      expect(await courierRepository.findById(requestId), isNull);
      expect(remoteSink.deleted, contains(requestId));
    });

    test('échoue proprement si la demande n\'existe pas', () async {
      final result = await service.deleteRequest('inconnue');
      expect(result.isFailure, isTrue);
    });
  });

  group('CourierService.purgeClosedForCoursier — ménage de l\'historique', () {
    test('supprime uniquement les demandes closes, jamais celles en attente',
        () async {
      final coursierId = await coursierId0();

      // Demande 1 : sera traitée (close).
      final closeResult = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );
      final closeId = closeResult.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );
      await service.openRequest(closeId);
      await service.respond(
        requestId: closeId,
        resultat: CourierRequestResult.retrouve,
      );

      // Demande 2 : reste ouverte (encore "Reçue").
      final openResult = await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 1,
        emplacement: 'Rayon B1',
      );
      final openId = openResult.when(
        success: (r) => r.id,
        failure: (_) => fail('devrait réussir'),
      );

      await service.purgeClosedForCoursier(coursierId);

      expect(await courierRepository.findById(closeId), isNull);
      expect(await courierRepository.findById(openId), isNotNull);
    });
  });

  group('CourierService.watchRequestsForCoursier — synchronisation en direct', () {
    Future<void> attendreEvenement(List<Object?> events, int minimum) {
      return Future.doWhile(() async {
        if (events.length >= minimum) return false;
        await Future.delayed(const Duration(milliseconds: 5));
        return true;
      });
    }

    test(
        'émet la liste locale immédiatement, puis une liste à jour dès '
        'qu\'une demande arrive côté serveur', () async {
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      final events = <List<String>>[];
      final sub = service
          .watchRequestsForCoursier(coursierId)
          .listen((requests) => events.add(requests.map((r) => r.id).toList()));

      await attendreEvenement(events, 1);
      expect(events.single, hasLength(1));

      remoteSource.emitRequests([
        CourierRequest(
          id: 'depuis-un-autre-appareil',
          preparateurId: _preparateurId,
          coursierId: coursierId,
          tourId: _tourId,
          productLineId: _productLineId,
          quantiteDemandee: 2,
          emplacement: 'Rayon B3',
          dateCreation: DateTime.now(),
          etat: CourierRequestStatus.recue,
        ),
      ]);

      await attendreEvenement(events, 2);
      expect(events.last, hasLength(2));
      expect(events.last, contains('depuis-un-autre-appareil'));

      await sub.cancel();
    });

    test(
        'une panne du flux distant n\'interrompt jamais le flux — les '
        'demandes locales déjà connues restent affichées', () async {
      final coursierId = await coursierId0();
      await service.createRequest(
        preparateurId: _preparateurId,
        coursierId: coursierId,
        tourId: _tourId,
        productLineId: _productLineId,
        quantiteDemandee: 3,
        emplacement: 'Rayon A2',
      );

      final events = <List<String>>[];
      var erreurRecue = false;
      var fluxFerme = false;
      final sub = service.watchRequestsForCoursier(coursierId).listen(
            (requests) => events.add(requests.map((r) => r.id).toList()),
            onError: (_) => erreurRecue = true,
            onDone: () => fluxFerme = true,
          );

      await attendreEvenement(events, 1);
      expect(events.single, hasLength(1));

      remoteSource.emitWatchError(Exception('panne réseau simulée'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(erreurRecue, isFalse);
      expect(fluxFerme, isFalse);
      expect(events, hasLength(1));

      await sub.cancel();
    });
  });
}
