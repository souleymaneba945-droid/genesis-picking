import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/administration/domain/administration_service.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

import '../auth/fake_user_repository.dart';
import '../courier/fake_courier_repository.dart';
import '../tours/fake_tour_repository.dart';

void main() {
  late FakeTourRepository tourRepository;
  late FakeCourierRepository courierRepository;
  late FakeUserRepository userRepository;
  late AdministrationService service;

  setUp(() async {
    tourRepository = FakeTourRepository();
    courierRepository = FakeCourierRepository();
    userRepository = FakeUserRepository();
    service = AdministrationService(
      tourRepository: tourRepository,
      courierRepository: courierRepository,
      userRepository: userRepository,
    );

    await userRepository.create(
      identifiant: 'prep1',
      nomAffichage: 'Amadou',
      role: UserRole.preparateur,
      motDePasse: 'MotDePasse123',
    );
    await userRepository.create(
      identifiant: 'prep2',
      nomAffichage: 'Fatou',
      role: UserRole.preparateur,
      motDePasse: 'MotDePasse123',
    );

    await tourRepository.registerAvailableTour(
      tourId: 'tour-1',
      numeroTournee: 'T-0001',
      preparateurId: 'prep1',
    );
    await tourRepository.registerAvailableTour(
      tourId: 'tour-2',
      numeroTournee: 'T-0002',
      preparateurId: 'prep1',
    );
    await tourRepository.updateStatus(
      tourId: 'tour-2',
      statut: TourStatus.terminee,
    );
  });

  group('AdministrationService.tourneesEnCours / historiqueTournees', () {
    test('sépare correctement les tournées actives des tournées terminées', () async {
      final enCours = await service.tourneesEnCours();
      final historique = await service.historiqueTournees();

      expect(enCours.map((t) => t.id), ['tour-1']);
      expect(historique.map((t) => t.id), ['tour-2']);
    });
  });

  group('AdministrationService.preparateursActifs', () {
    test('ne renvoie que les préparateurs actifs', () async {
      final prep2 = await userRepository.findByIdentifiant('prep2');
      await userRepository.setActive(userId: prep2!.id, actif: false);

      final actifs = await service.preparateursActifs();

      expect(actifs.map((p) => p.nom), ['Amadou']);
    });
  });

  group('AdministrationService.reassignerTournee', () {
    test('réassigne correctement une tournée active', () async {
      final prep2 = await userRepository.findByIdentifiant('prep2');

      final result = await service.reassignerTournee(
        tourId: 'tour-1',
        newPreparateurId: prep2!.id,
      );

      expect(result.isSuccess, isTrue);
      final tour = await tourRepository.findById('tour-1');
      expect(tour!.preparateurId, prep2.id);
    });

    test('refuse de réassigner une tournée déjà terminée', () async {
      final prep2 = await userRepository.findByIdentifiant('prep2');

      final result = await service.reassignerTournee(
        tourId: 'tour-2',
        newPreparateurId: prep2!.id,
      );

      expect(result.isFailure, isTrue);
      final tour = await tourRepository.findById('tour-2');
      expect(tour!.preparateurId, 'prep1'); // inchangé
    });

    test('refuse la réassignation d\'une tournée introuvable', () async {
      final result = await service.reassignerTournee(
        tourId: 'inconnue',
        newPreparateurId: 'peu-importe',
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('AdministrationService.toutesLesDemandes', () {
    test('renvoie les demandes de tous les préparateurs et coursiers', () async {
      await courierRepository.create(
        preparateurId: 'prep1',
        coursierId: 'coursier1',
        tourId: 'tour-1',
        productLineId: 'prod-1',
        quantiteDemandee: 2,
        emplacement: 'Rayon A1',
      );
      await courierRepository.create(
        preparateurId: 'prep2',
        coursierId: 'coursier2',
        tourId: 'tour-1',
        productLineId: 'prod-2',
        quantiteDemandee: 1,
        emplacement: 'Rayon B2',
      );

      final demandes = await service.toutesLesDemandes();
      expect(demandes, hasLength(2));
    });
  });

  group('AdministrationService — analyse de vitesse de picking', () {
    test('historiqueAvecPreparateur associe chaque tournée au bon nom',
        () async {
      final historique = await service.historiqueAvecPreparateur();

      expect(historique, hasLength(1));
      expect(historique.single.tour.id, 'tour-2');
      expect(historique.single.preparateurNom, 'Amadou');
    });

    test(
        'moyennesVitesseParPreparateur ignore les tournées sans durée '
        'connue (dateDebut/dateFin absentes)', () async {
      // 'tour-2' (seule tournée terminée) n'a ni dateDebut ni dateFin
      // dans le setUp — aucune durée à moyenner.
      final moyennes = await service.moyennesVitesseParPreparateur();
      expect(moyennes, isEmpty);
    });

    test(
        'moyennesVitesseParPreparateur calcule correctement une moyenne '
        'sur plusieurs tournées du même préparateur', () async {
      final debut = DateTime(2026, 1, 1, 8);
      await tourRepository.registerAvailableTour(
        tourId: 'tour-3',
        numeroTournee: 'T-0003',
        preparateurId: 'prep1',
      );
      // 10 minutes.
      await tourRepository.updateStatus(
        tourId: 'tour-2',
        statut: TourStatus.terminee,
        dateDebut: debut,
        dateFin: debut.add(const Duration(minutes: 10)),
      );
      // 20 minutes.
      await tourRepository.updateStatus(
        tourId: 'tour-3',
        statut: TourStatus.terminee,
        dateDebut: debut,
        dateFin: debut.add(const Duration(minutes: 20)),
      );

      final moyennes = await service.moyennesVitesseParPreparateur();

      expect(moyennes, hasLength(1));
      expect(moyennes.single.preparateurNom, 'Amadou');
      expect(moyennes.single.nombreTournees, 2);
      expect(moyennes.single.dureeMoyenne, const Duration(minutes: 15));
    });

    test('trie les préparateurs du plus rapide au plus lent en moyenne',
        () async {
      final debut = DateTime(2026, 1, 1, 8);
      await tourRepository.registerAvailableTour(
        tourId: 'tour-lente',
        numeroTournee: 'T-LENTE',
        preparateurId: 'prep2',
      );
      await tourRepository.updateStatus(
        tourId: 'tour-2', // prep1 : 5 min
        statut: TourStatus.terminee,
        dateDebut: debut,
        dateFin: debut.add(const Duration(minutes: 5)),
      );
      await tourRepository.updateStatus(
        tourId: 'tour-lente', // prep2 : 30 min
        statut: TourStatus.terminee,
        dateDebut: debut,
        dateFin: debut.add(const Duration(minutes: 30)),
      );

      final moyennes = await service.moyennesVitesseParPreparateur();

      expect(moyennes.map((m) => m.preparateurNom), ['Amadou', 'Fatou']);
    });
  });
}
