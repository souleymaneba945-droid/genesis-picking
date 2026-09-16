import 'package:flutter_test/flutter_test.dart';

import 'fake_brand_warehouse_location_repository.dart';

void main() {
  late FakeBrandWarehouseLocationRepository repository;

  setUp(() {
    repository = FakeBrandWarehouseLocationRepository();
  });

  group('BrandWarehouseLocationRepository.create — unicité de la marque', () {
    test('crée normalement une première marque', () async {
      final result = await repository.create(marque: 'Mustela', emplacement: 'Zone A');
      expect(result.isSuccess, isTrue);
      expect(await repository.listAll(), hasLength(1));
    });

    test('refuse une marque déjà utilisée (même casse)', () async {
      await repository.create(marque: 'Mustela', emplacement: 'Zone A');
      final result = await repository.create(marque: 'Mustela', emplacement: 'Zone B');
      expect(result.isFailure, isTrue);
      expect(await repository.listAll(), hasLength(1));
    });

    test('refuse une marque déjà utilisée, casse différente', () async {
      await repository.create(marque: 'Mustela', emplacement: 'Zone A');
      final result = await repository.create(marque: 'MUSTELA', emplacement: 'Zone B');
      expect(result.isFailure, isTrue);
    });
  });

  group('BrandWarehouseLocationRepository.update', () {
    test('modifie l\'emplacement d\'une marque existante', () async {
      final created = await repository.create(marque: 'Mustela', emplacement: 'Zone A');
      final id = created.when(success: (l) => l.id, failure: (_) => fail('devrait réussir'));

      final result = await repository.update(
        id: id,
        marque: 'Mustela',
        emplacement: 'Zone Z',
      );

      expect(result.isSuccess, isTrue);
      final all = await repository.listAll();
      expect(all.single.emplacement, 'Zone Z');
    });

    test('refuse de renommer vers une marque déjà utilisée par une autre entrée',
        () async {
      await repository.create(marque: 'Mustela', emplacement: 'Zone A');
      final second = await repository.create(marque: 'Topicrem', emplacement: 'Zone B');
      final secondId =
          second.when(success: (l) => l.id, failure: (_) => fail('devrait réussir'));

      final result = await repository.update(
        id: secondId,
        marque: 'Mustela',
        emplacement: 'Zone B',
      );

      expect(result.isFailure, isTrue);
    });
  });

  group('BrandWarehouseLocationRepository.upsertFromRemote', () {
    test(
      'un doublon local (même marque, id différent) est remplacé par la '
      'version du serveur',
      () async {
        await repository.create(marque: 'Mustela', emplacement: 'Zone A');

        await repository.upsertFromRemote(
          id: 'id-serveur',
          marque: 'Mustela',
          emplacement: 'Zone Serveur',
        );

        final all = await repository.listAll();
        expect(all, hasLength(1));
        expect(all.single.id, 'id-serveur');
        expect(all.single.emplacement, 'Zone Serveur');
      },
    );
  });
}
