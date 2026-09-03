import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

import 'fake_tour_repository.dart';

void main() {
  group('TourRepository (contrat, via FakeTourRepository)', () {
    test('stockage local : une tournée est accessible sans réseau une fois enregistrée', () async {
      final repository = FakeTourRepository();
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

      final tour = await repository.findById('tour-1');
      expect(tour, isNotNull);
      expect(tour!.estTeleChargeeLocalement, isTrue);
      expect(await repository.countProductLines('tour-1'), 1);
    });

    test('doublons : registerAvailableTour n\'écrase jamais une tournée déjà téléchargée', () async {
      final repository = FakeTourRepository();
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

      // Le logiciel de gestion signale à nouveau la même tournée comme
      // "disponible" — ne doit rien changer à l'état déjà téléchargé.
      await repository.registerAvailableTour(
        tourId: 'tour-1',
        numeroTournee: 'T-2026-0001',
        preparateurId: 'prep-1',
      );

      final tour = await repository.findById('tour-1');
      expect(tour!.statut, TourStatus.telechargee);
    });

    test('changement d\'état : updateStatus modifie uniquement le statut ciblé', () async {
      final repository = FakeTourRepository();
      await repository.registerAvailableTour(
        tourId: 'tour-1',
        numeroTournee: 'T-2026-0001',
        preparateurId: 'prep-1',
      );

      await repository.updateStatus(
        tourId: 'tour-1',
        statut: TourStatus.enCours,
      );

      final tour = await repository.findById('tour-1');
      expect(tour!.statut, TourStatus.enCours);
      expect(tour.numeroTournee, 'T-2026-0001'); // reste inchangé
    });

    test('les tournées sont filtrées par préparateur', () async {
      final repository = FakeTourRepository();
      await repository.registerAvailableTour(
        tourId: 'tour-1',
        numeroTournee: 'T-2026-0001',
        preparateurId: 'prep-1',
      );
      await repository.registerAvailableTour(
        tourId: 'tour-2',
        numeroTournee: 'T-2026-0002',
        preparateurId: 'prep-2',
      );

      final toursPrep1 = await repository.listForPreparateur('prep-1');
      expect(toursPrep1.map((t) => t.id), ['tour-1']);
    });
  });
}
