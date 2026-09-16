import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/administration/domain/demand_stats.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';

int _n = 0;
CourierRequest _demande({
  String? produitNom,
  String? produitDescription,
  String emplacement = 'A1',
  CourierRequestResult? resultat,
  CourierRequestStatus etat = CourierRequestStatus.recue,
}) {
  _n++;
  return CourierRequest(
    id: 'r-$_n',
    preparateurId: 'prep-1',
    coursierId: 'coursier-1',
    tourId: 'tour-1',
    productLineId: 'ligne-$_n',
    quantiteDemandee: 1,
    emplacement: emplacement,
    dateCreation: DateTime(2026, 9, 16),
    etat: etat,
    resultat: resultat,
    produitNom: produitNom,
    produitDescription: produitDescription,
  );
}

const _marques = [
  BrandWarehouseLocation(id: '1', marque: 'Mustela', emplacement: 'Zone A'),
];

void main() {
  group('classifyDemand — Module 5 v2, Rubrique 4ter (statistiques de demande)', () {
    test('≥ 75% du max → très forte demande', () {
      expect(classifyDemand(75, 100), DemandClassification.tresForte);
      expect(classifyDemand(100, 100), DemandClassification.tresForte);
    });

    test('≥ 50% et < 75% → forte demande', () {
      expect(classifyDemand(50, 100), DemandClassification.forte);
      expect(classifyDemand(74, 100), DemandClassification.forte);
    });

    test('≥ 25% et < 50% → demande modérée', () {
      expect(classifyDemand(25, 100), DemandClassification.moderee);
    });

    test('< 25% → faible demande', () {
      expect(classifyDemand(1, 100), DemandClassification.faible);
    });

    test('aucun maximum (période vide) → faible demande, jamais une erreur', () {
      expect(classifyDemand(0, 0), DemandClassification.faible);
    });
  });

  group('pickingPriorityFor', () {
    test('la priorité picking découle 1:1 de la classification', () {
      expect(pickingPriorityFor(DemandClassification.tresForte), PickingPriority.prioritePicking);
      expect(pickingPriorityFor(DemandClassification.forte), PickingPriority.aRapprocher);
      expect(pickingPriorityFor(DemandClassification.moderee), PickingPriority.aSurveiller);
      expect(pickingPriorityFor(DemandClassification.faible), PickingPriority.organisationStandard);
    });
  });

  group('computeTrend', () {
    test('pas de période précédente → données insuffisantes', () {
      final trend = computeTrend(10, 0);
      expect(trend.direction, DemandTrendDirection.insuffisant);
      expect(trend.variationPourcent, isNull);
    });

    test('+15% ou plus → hausse', () {
      final trend = computeTrend(23, 20); // +15%
      expect(trend.direction, DemandTrendDirection.hausse);
      expect(trend.variationPourcent, closeTo(15, 0.01));
    });

    test('-15% ou moins → baisse', () {
      final trend = computeTrend(17, 20); // -15%
      expect(trend.direction, DemandTrendDirection.baisse);
    });

    test('entre les deux → stable', () {
      final trend = computeTrend(21, 20); // +5%
      expect(trend.direction, DemandTrendDirection.stable);
    });

    test('exemple du cahier des charges : 28 → 45 recherches (+60,7%)', () {
      final trend = computeTrend(45, 28);
      expect(trend.direction, DemandTrendDirection.hausse);
      expect(trend.variationPourcent, closeTo(60.7, 0.1));
    });
  });

  group('computeProductDemandStats', () {
    test('regroupe par référence exacte (SKU), jamais par nom seul si la référence existe', () {
      final stats = computeProductDemandStats(
        demandesPeriode: [
          _demande(produitNom: 'Crème Mustela', produitDescription: 'REF-1'),
          _demande(produitNom: 'Crème Mustela', produitDescription: 'REF-1'),
          _demande(produitNom: 'Crème Mustela', produitDescription: 'REF-2'),
        ],
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      expect(stats, hasLength(2));
      final ref1 = stats.firstWhere((s) => s.sku == 'REF-1');
      expect(ref1.total, 2);
    });

    test('sans référence → regroupé par nom (contrairement à la Rubrique 1)', () {
      final stats = computeProductDemandStats(
        demandesPeriode: [
          _demande(produitNom: 'Vaseline 72h'),
          _demande(produitNom: 'Vaseline 72h'),
        ],
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      expect(stats.single.total, 2);
      expect(stats.single.sku, isNull);
    });

    test('marque déduite via la même règle que l\'emplacement entrepôt', () {
      final stats = computeProductDemandStats(
        demandesPeriode: [_demande(produitNom: 'Mustela Gel Lavant', produitDescription: 'REF-1')],
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      expect(stats.single.marque, 'Mustela');
    });

    test('part de la demande = total du produit / total de la période × 100', () {
      final stats = computeProductDemandStats(
        demandesPeriode: [
          _demande(produitDescription: 'REF-1'),
          _demande(produitDescription: 'REF-1'),
          _demande(produitDescription: 'REF-2'),
          _demande(produitDescription: 'REF-2'),
          _demande(produitDescription: 'REF-2'),
          _demande(produitDescription: 'REF-2'),
        ],
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      final ref2 = stats.firstWhere((s) => s.sku == 'REF-2');
      expect(ref2.partDemandePourcent, closeTo(66.67, 0.1));
    });

    test('trié du plus demandé au moins demandé', () {
      final stats = computeProductDemandStats(
        demandesPeriode: [
          _demande(produitDescription: 'REF-1'),
          _demande(produitDescription: 'REF-2'),
          _demande(produitDescription: 'REF-2'),
          _demande(produitDescription: 'REF-2'),
        ],
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      expect(stats.first.sku, 'REF-2');
    });

    test('tendance calculée par rapport à la période précédente, même clé de regroupement', () {
      final stats = computeProductDemandStats(
        demandesPeriode: List.generate(23, (_) => _demande(produitDescription: 'REF-1')),
        demandesPeriodePrecedente: List.generate(20, (_) => _demande(produitDescription: 'REF-1')),
        marques: _marques,
      );

      expect(stats.single.trend.direction, DemandTrendDirection.hausse);
    });

    test('ventile trouvés/non trouvés/en cours sans double-compter', () {
      final stats = computeProductDemandStats(
        demandesPeriode: [
          _demande(produitDescription: 'REF-1', resultat: CourierRequestResult.retrouve),
          _demande(produitDescription: 'REF-1', resultat: CourierRequestResult.nonRetrouve),
          _demande(produitDescription: 'REF-1'),
        ],
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      final stat = stats.single;
      expect(stat.total, 3);
      expect(stat.trouves, 1);
      expect(stat.nonTrouves, 1);
      expect(stat.enCours, 1);
    });

    test('aucune demande sur la période → liste vide, jamais une erreur', () {
      expect(
        computeProductDemandStats(
          demandesPeriode: const [],
          demandesPeriodePrecedente: const [],
          marques: _marques,
        ),
        isEmpty,
      );
    });
  });

  group('computeBrandDemandStats', () {
    test('regroupe les statistiques produit déjà calculées par marque', () {
      final produits = computeProductDemandStats(
        demandesPeriode: [
          _demande(produitNom: 'Mustela Gel', produitDescription: 'REF-1'),
          _demande(produitNom: 'Mustela Crème', produitDescription: 'REF-2'),
          _demande(produitNom: 'Vaseline', produitDescription: 'REF-3'),
        ],
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      final marques = computeBrandDemandStats(produits, const []);
      final mustela = marques.firstWhere((m) => m.marque == 'Mustela');
      expect(mustela.total, 2);
      expect(mustela.produitsDistincts, 2);
    });
  });

  group('computeLocationDemandStats', () {
    test('regroupe par emplacement de picking, jamais l\'emplacement entrepôt', () {
      final demandes = [
        _demande(produitDescription: 'REF-1', emplacement: 'A1'),
        _demande(produitDescription: 'REF-1', emplacement: 'A1'),
        _demande(produitDescription: 'REF-2', emplacement: 'B2'),
      ];
      final produits = computeProductDemandStats(
        demandesPeriode: demandes,
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      final locations = computeLocationDemandStats(produits, demandes);

      final a1 = locations.firstWhere((l) => l.emplacement == 'A1');
      expect(a1.total, 2);
      expect(a1.produitsDistincts, 1);
    });

    test('taux de non trouvés calculé correctement', () {
      final demandes = [
        _demande(produitDescription: 'REF-1', emplacement: 'A1', resultat: CourierRequestResult.nonRetrouve),
        _demande(produitDescription: 'REF-1', emplacement: 'A1', resultat: CourierRequestResult.retrouve),
      ];
      final produits = computeProductDemandStats(
        demandesPeriode: demandes,
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      final a1 = computeLocationDemandStats(produits, demandes).single;
      expect(a1.tauxNonTrouvePourcent, closeTo(50, 0.01));
    });
  });

  group('genererObservationsLogistiques', () {
    test('aucune donnée → aucune observation', () {
      expect(genererObservationsLogistiques(const [], 0), isEmpty);
    });

    test('ne prétend jamais qu\'un produit est en rupture', () {
      final produits = computeProductDemandStats(
        demandesPeriode: List.generate(80, (_) => _demande(produitDescription: 'REF-1')),
        demandesPeriodePrecedente: const [],
        marques: _marques,
      );

      final observations = genererObservationsLogistiques(produits, 80);

      for (final o in observations) {
        expect(o.toLowerCase(), isNot(contains('rupture')));
        expect(o.toLowerCase(), isNot(contains('stock')));
      }
    });
  });
}
