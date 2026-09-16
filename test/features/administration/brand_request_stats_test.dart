import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/administration/domain/brand_request_stats.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';

CourierRequest _demande({
  required String id,
  String? produitNom,
  CourierRequestStatus etat = CourierRequestStatus.recue,
  CourierRequestResult? resultat,
}) {
  return CourierRequest(
    id: id,
    preparateurId: 'prep-1',
    coursierId: 'coursier-1',
    tourId: 'tour-1',
    productLineId: 'ligne-$id',
    quantiteDemandee: 1,
    emplacement: 'A1',
    dateCreation: DateTime(2026, 9, 16),
    etat: etat,
    resultat: resultat,
    produitNom: produitNom,
  );
}

void main() {
  group(
    'computeBrandRequestStats — Module 5 v2, Rubrique 4bis (statistiques par marque)',
    () {
      const marques = [
        BrandWarehouseLocation(id: '1', marque: 'Mustela', emplacement: 'Zone A'),
        BrandWarehouseLocation(id: '2', marque: 'Nivea', emplacement: 'Zone B'),
      ];

      test('regroupe les demandes par marque reconnue (même règle que le picking)', () {
        final stats = computeBrandRequestStats([
          _demande(id: '1', produitNom: 'Mustela Gel Lavant'),
          _demande(id: '2', produitNom: 'MUSTELA Crème Visage'),
          _demande(id: '3', produitNom: 'Nivea Soft'),
        ], marques);

        final mustela = stats.firstWhere((s) => s.marque == 'Mustela');
        final nivea = stats.firstWhere((s) => s.marque == 'Nivea');
        expect(mustela.total, 2);
        expect(nivea.total, 1);
      });

      test('trié du plus fréquent au moins fréquent', () {
        final stats = computeBrandRequestStats([
          _demande(id: '1', produitNom: 'Nivea Soft'),
          _demande(id: '2', produitNom: 'Mustela Gel'),
          _demande(id: '3', produitNom: 'Mustela Crème'),
          _demande(id: '4', produitNom: 'Mustela Lait'),
        ], marques);

        expect(stats.first.marque, 'Mustela');
        expect(stats.first.total, 3);
      });

      test(
        'produit sans marque reconnue → regroupé sous "Marque non identifiée", '
        'jamais fusionné avec une vraie marque',
        () {
          final stats = computeBrandRequestStats([
            _demande(id: '1', produitNom: 'Vaseline 72h'),
          ], marques);

          expect(stats.single.marque, marqueNonIdentifiee);
        },
      );

      test('demande sans nom de produit (donnée ancienne) → même panier "non identifiée"', () {
        final stats = computeBrandRequestStats([
          _demande(id: '1', produitNom: null),
        ], marques);

        expect(stats.single.marque, marqueNonIdentifiee);
      });

      test(
        'ventile trouvés / non trouvés / en cours SANS double-compter',
        () {
          final stats = computeBrandRequestStats([
            _demande(
              id: '1',
              produitNom: 'Mustela Gel',
              etat: CourierRequestStatus.traitee,
              resultat: CourierRequestResult.nonRetrouve,
            ),
            _demande(
              id: '2',
              produitNom: 'Mustela Crème',
              etat: CourierRequestStatus.traitee,
              resultat: CourierRequestResult.retrouve,
            ),
            _demande(
              id: '3',
              produitNom: 'Mustela Lait',
              etat: CourierRequestStatus.acceptee,
            ),
          ], marques);

          final mustela = stats.single;
          expect(mustela.total, 3);
          expect(mustela.nonTrouves, 1);
          expect(mustela.trouves, 1);
          expect(mustela.enCours, 1);
        },
      );

      test('aucune demande → liste vide, jamais une erreur', () {
        expect(computeBrandRequestStats(const [], marques), isEmpty);
      });
    },
  );
}
