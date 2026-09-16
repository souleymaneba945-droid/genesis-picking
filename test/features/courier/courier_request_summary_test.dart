import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/courier/data/courier_request_summary.dart';

CourierRequestSummary _summary({
  required String id,
  required String preparateurNom,
  String? produitDescription,
  String produitNom = 'Produit',
}) {
  return CourierRequestSummary(
    request: CourierRequest(
      id: id,
      preparateurId: 'prep-$id',
      coursierId: 'coursier-1',
      tourId: 'tour-1',
      productLineId: 'ligne-$id',
      quantiteDemandee: 1,
      emplacement: 'A1',
      dateCreation: DateTime(2026, 9, 9),
      etat: CourierRequestStatus.recue,
    ),
    preparateurNom: preparateurNom,
    produitNom: produitNom,
    produitDescription: produitDescription,
  );
}

void main() {
  group('groupCourierRequestsByProduct — Module 5 v2, Rubrique 1', () {
    test(
      'deux demandes de deux préparateurs différents, même référence '
      'exacte → un seul groupe',
      () {
        final resultats = groupCourierRequestsByProduct([
          _summary(id: 'r1', preparateurNom: 'Souleymane', produitDescription: '234187 - 8800256119660'),
          _summary(id: 'r2', preparateurNom: 'Mouhamed', produitDescription: '234187 - 8800256119660'),
        ]);

        expect(resultats, hasLength(1));
        expect(resultats.single.requests, hasLength(2));
        expect(resultats.single.requestIds, containsAll(['r1', 'r2']));
      },
    );

    test('références différentes → deux groupes distincts', () {
      final resultats = groupCourierRequestsByProduct([
        _summary(id: 'r1', preparateurNom: 'Souleymane', produitDescription: 'REF-A'),
        _summary(id: 'r2', preparateurNom: 'Mouhamed', produitDescription: 'REF-B'),
      ]);

      expect(resultats, hasLength(2));
    });

    test(
      'référence absente (null) → jamais fusionnée, même avec une autre '
      'demande elle aussi sans référence',
      () {
        final resultats = groupCourierRequestsByProduct([
          _summary(id: 'r1', preparateurNom: 'Souleymane'),
          _summary(id: 'r2', preparateurNom: 'Mouhamed'),
        ]);

        expect(resultats, hasLength(2));
        expect(resultats.every((g) => g.requests.length == 1), isTrue);
      },
    );

    test('référence vide (chaîne vide) → jamais fusionnée non plus', () {
      final resultats = groupCourierRequestsByProduct([
        _summary(id: 'r1', preparateurNom: 'Souleymane', produitDescription: ''),
        _summary(id: 'r2', preparateurNom: 'Mouhamed', produitDescription: ''),
      ]);

      expect(resultats, hasLength(2));
    });

    test('liste vide → aucun groupe', () {
      expect(groupCourierRequestsByProduct(const []), isEmpty);
    });

    test('conserve nom/description/image pris sur le premier élément du groupe', () {
      final resultats = groupCourierRequestsByProduct([
        _summary(
          id: 'r1',
          preparateurNom: 'Souleymane',
          produitDescription: 'REF-A',
          produitNom: 'Vaseline 72h',
        ),
        _summary(
          id: 'r2',
          preparateurNom: 'Mouhamed',
          produitDescription: 'REF-A',
          produitNom: 'Vaseline 72h',
        ),
      ]);

      expect(resultats.single.produitNom, 'Vaseline 72h');
      expect(resultats.single.produitDescription, 'REF-A');
    });
  });
}
