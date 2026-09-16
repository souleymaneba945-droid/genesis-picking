import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/warehouse_location/domain/warehouse_location_service.dart';

import 'fake_brand_warehouse_location_repository.dart';

void main() {
  late FakeBrandWarehouseLocationRepository repository;
  late WarehouseLocationService service;

  setUp(() {
    repository = FakeBrandWarehouseLocationRepository();
    service = WarehouseLocationService(repository);
  });

  group('WarehouseLocationService.findEmplacement — Module 5 v2, Rubrique 2', () {
    test('le nom du produit commence par une marque connue → emplacement trouvé',
        () async {
      await repository.create(marque: 'Mustela', emplacement: 'Zone A');

      final emplacement =
          await service.findEmplacement('Mustela Gel Lavant Doux Corps et cheveux');

      expect(emplacement, 'Zone A');
    });

    test('comparaison insensible à la casse', () async {
      await repository.create(marque: 'topicrem', emplacement: 'Zone B');

      final emplacement = await service.findEmplacement('TOPICREM Ultra Hydratant');

      expect(emplacement, 'Zone B');
    });

    test('la marque doit être en DÉBUT de nom, jamais n\'importe où dedans',
        () async {
      await repository.create(marque: 'Cream', emplacement: 'Zone C');

      final emplacement = await service.findEmplacement('Mustela Baby Cream');

      expect(emplacement, isNull);
    });

    test(
      'plusieurs marques correspondantes (une préfixe de l\'autre) → la plus '
      'longue (la plus spécifique) l\'emporte',
      () async {
        await repository.create(marque: 'Mary', emplacement: 'Zone D');
        await repository.create(marque: 'Mary and May', emplacement: 'Zone E');

        final emplacement =
            await service.findEmplacement('Mary and May Crème Contour Yeux');

        expect(emplacement, 'Zone E');
      },
    );

    test('aucune marque connue ne correspond → null', () async {
      await repository.create(marque: 'Mustela', emplacement: 'Zone A');

      final emplacement = await service.findEmplacement('Vaseline 72h');

      expect(emplacement, isNull);
    });

    test('aucune marque enregistrée du tout → null, jamais une erreur', () async {
      final emplacement = await service.findEmplacement('N\'importe quel produit');
      expect(emplacement, isNull);
    });
  });
}
