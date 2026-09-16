import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/administration/domain/stats_period.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

CourierRequest _demande(DateTime dateCreation) {
  return CourierRequest(
    id: 'r-${dateCreation.toIso8601String()}',
    preparateurId: 'prep-1',
    coursierId: 'coursier-1',
    tourId: 'tour-1',
    productLineId: 'ligne-1',
    quantiteDemandee: 1,
    emplacement: 'A1',
    dateCreation: dateCreation,
    etat: CourierRequestStatus.recue,
  );
}

void main() {
  group('periodBounds — Module 5 v2, Rubrique 4bis (statistiques jour/semaine/mois)', () {
    test('jour : bornes exactement sur le jour civil', () {
      final (debut, fin) = periodBounds(
        DateTime(2026, 9, 16, 14, 30),
        StatsPeriodGranularity.jour,
      );
      expect(debut, DateTime(2026, 9, 16));
      expect(fin, DateTime(2026, 9, 17));
    });

    test('semaine : commence le lundi, quel que soit le jour de référence', () {
      // Le 16/09/2026 est un mercredi.
      final (debut, fin) = periodBounds(
        DateTime(2026, 9, 16),
        StatsPeriodGranularity.semaine,
      );
      expect(debut, DateTime(2026, 9, 14)); // lundi
      expect(fin, DateTime(2026, 9, 21)); // lundi suivant
    });

    test('semaine : un dimanche appartient toujours à SA semaine (celle qui se termine ce jour-là)', () {
      final (debut, fin) = periodBounds(
        DateTime(2026, 9, 20), // dimanche
        StatsPeriodGranularity.semaine,
      );
      expect(debut, DateTime(2026, 9, 14));
      expect(fin, DateTime(2026, 9, 21));
    });

    test('mois : bornes du 1er au 1er du mois suivant', () {
      final (debut, fin) = periodBounds(
        DateTime(2026, 9, 16),
        StatsPeriodGranularity.mois,
      );
      expect(debut, DateTime(2026, 9, 1));
      expect(fin, DateTime(2026, 10, 1));
    });

    test('mois : décembre bascule correctement sur janvier de l\'année suivante', () {
      final (debut, fin) = periodBounds(
        DateTime(2026, 12, 25),
        StatsPeriodGranularity.mois,
      );
      expect(debut, DateTime(2026, 12, 1));
      expect(fin, DateTime(2027, 1, 1));
    });
  });

  group('shiftPeriod', () {
    test('jour : +1/-1 jour', () {
      final ref = DateTime(2026, 9, 16);
      expect(shiftPeriod(ref, StatsPeriodGranularity.jour, 1), DateTime(2026, 9, 17));
      expect(shiftPeriod(ref, StatsPeriodGranularity.jour, -1), DateTime(2026, 9, 15));
    });

    test('semaine : +1/-1 semaine (7 jours)', () {
      final ref = DateTime(2026, 9, 16);
      expect(shiftPeriod(ref, StatsPeriodGranularity.semaine, 1), DateTime(2026, 9, 23));
    });

    test('mois : janvier -1 mois retombe sur décembre de l\'année précédente', () {
      final ref = DateTime(2027, 1, 15);
      final precedent = shiftPeriod(ref, StatsPeriodGranularity.mois, -1);
      expect(precedent.year, 2026);
      expect(precedent.month, 12);
    });
  });

  group('filterByPeriod', () {
    test('garde uniquement les demandes créées dans [début, finExclue)', () {
      final demandes = [
        _demande(DateTime(2026, 9, 15, 23, 59)), // avant
        _demande(DateTime(2026, 9, 16, 0, 0)), // pile au début — inclus
        _demande(DateTime(2026, 9, 16, 12)), // dedans
        _demande(DateTime(2026, 9, 17, 0, 0)), // pile à la fin — exclu
      ];

      final resultat = filterByPeriod(demandes, DateTime(2026, 9, 16), DateTime(2026, 9, 17));

      expect(resultat, hasLength(2));
    });
  });

  group('periodLabel', () {
    test('mois : nom du mois capitalisé + année', () {
      final label = periodLabel(
        DateTime(2026, 9, 1),
        DateTime(2026, 10, 1),
        StatsPeriodGranularity.mois,
      );
      expect(label, 'Septembre 2026');
    });

    test('semaine : "Semaine du ... au ..."', () {
      final label = periodLabel(
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 21),
        StatsPeriodGranularity.semaine,
      );
      expect(label, 'Semaine du 14/09 au 20/09/2026');
    });
  });
}
