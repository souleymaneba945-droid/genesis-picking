import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';
import 'package:genesis_picking/features/import/domain/import_engine.dart';
import 'package:genesis_picking/features/import/domain/import_validator.dart';

import '../tours/fake_tour_repository.dart';
import 'fake_import_parser.dart';
import 'fake_import_repository.dart';
import 'fake_tour_remote_sink.dart';

final _sourceFactice = ImportSource(bytes: Uint8List(0), fileName: 'test.pdf');

const _tourneeValide = ParsedTournee(
  numeroTournee: 'T-2026-0001',
  produits: [
    ParsedProduit(
      ligneSource: 1,
      nom: 'Savon Kojie San',
      emplacement: 'Rayon A1',
      quantiteDemandee: 3,
    ),
    ParsedProduit(
      ligneSource: 2,
      nom: 'Crème CeraVe',
      emplacement: 'Rayon B2',
      quantiteDemandee: 1,
    ),
  ],
);

void main() {
  late FakeImportParser parser;
  late FakeTourRepository tourRepository;
  late FakeImportRepository importRepository;
  late FakeTourRemoteSink tourRemoteSink;
  late ImportEngine engine;

  setUp(() {
    parser = FakeImportParser(result: _tourneeValide);
    tourRepository = FakeTourRepository();
    importRepository = FakeImportRepository();
    tourRemoteSink = FakeTourRemoteSink();
    engine = ImportEngine(
      parsers: [parser],
      validator: ImportValidator(),
      tourRepository: tourRepository,
      importRepository: importRepository,
      tourRemoteSink: tourRemoteSink,
    );
  });

  group('ImportEngine — petit fichier', () {
    test('importe correctement une tournée valide', () async {
      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isTrue);
      expect(report.nombreProduits, 2);
      expect(report.tourId, isNotNull);

      final tour = await tourRepository.findById(report.tourId!);
      expect(tour, isNotNull);
      expect(tour!.estTeleChargeeLocalement, isTrue);
    });

    test('enregistre l\'import dans l\'historique', () async {
      await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );
      final historique = await importRepository.history();
      expect(historique, hasLength(1));
      expect(historique.single.succes, isTrue);
    });
  });

  group('ImportEngine — fichier incomplet', () {
    test('refuse et ne persiste rien si un produit a une erreur bloquante', () async {
      parser.result = const ParsedTournee(
        numeroTournee: 'T-2026-0002',
        produits: [ParsedProduit(ligneSource: 1, nom: 'Sans quantité')],
      );

      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isFalse);
      expect(report.erreurs, isNotEmpty);
      expect(await tourRepository.listAll(), isEmpty);
    });

    test('image manquante seule → import accepté avec avertissement', () async {
      parser.result = const ParsedTournee(
        numeroTournee: 'T-2026-0003',
        produits: [
          ParsedProduit(
            ligneSource: 1,
            nom: 'Savon',
            emplacement: 'A1',
            quantiteDemandee: 1,
          ),
        ],
      );

      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isTrue);
      expect(report.avertissements, isNotEmpty);
    });
  });

  group('ImportEngine — erreur de structure', () {
    test('erreur du parser → rapport d\'échec, jamais une exception', () async {
      parser.errorToThrow = const ImportStructureException(
        'Fichier corrompu.',
      );

      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isFalse);
      expect(report.erreurs.single.message, 'Fichier corrompu.');
    });

    test('erreur totalement imprévue du parser → jamais une exception non gérée', () async {
      parser.errorToThrow = Exception('boom');

      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isFalse);
    });

    test('format non enregistré → rapport d\'échec propre', () async {
      final report = await engine.import(
        format: ImportFormat.csv, // aucun CsvParser enregistré ici
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isFalse);
      expect(parser.parseCallCount, 0);
    });
  });

  group('ImportEngine — doublons et reprise', () {
    test('réimporter la même tournée ne duplique rien', () async {
      final premier = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );
      final second = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(premier.tourId, second.tourId);
      expect(second.dejaImportee, isTrue);
      expect(tourRepository.saveCallCount, 1); // une seule écriture réelle
    });

    test('import interrompu simulé : reprendre en réimportant retrouve le même identifiant', () async {
      // Simule une interruption : le premier import échoue avant la
      // persistance (ex. app fermée pendant l'analyse).
      parser.errorToThrow = const ImportStructureException('Interrompu');
      final echoue = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );
      expect(echoue.succes, isFalse);
      expect(await tourRepository.listAll(), isEmpty);

      // Reprise : on relance le même import, cette fois sans erreur.
      parser.errorToThrow = null;
      final reussi = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(reussi.succes, isTrue);
      expect(await tourRepository.listAll(), hasLength(1));
    });
  });

  group('ImportEngine — gros volume', () {
    test('importe correctement une tournée de plusieurs centaines de produits', () async {
      parser.result = ParsedTournee(
        numeroTournee: 'T-2026-GROS',
        produits: List.generate(
          400,
          (i) => ParsedProduit(
            ligneSource: i + 1,
            nom: 'Produit $i',
            emplacement: 'Rayon $i',
            quantiteDemandee: 1,
          ),
        ),
      );

      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isTrue);
      expect(report.nombreProduits, 400);
    });
  });

  group('ImportEngine — transmission au serveur central', () {
    test('transmet la tournée importée après l\'avoir stockée localement',
        () async {
      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isTrue);
      expect(tourRemoteSink.pushed, hasLength(1));
      final pushed = tourRemoteSink.pushed.single;
      expect(pushed.tourId, report.tourId);
      expect(pushed.numeroTournee, 'T-2026-0001');
      expect(pushed.preparateurId, 'prep-1');
      expect(pushed.produits, hasLength(2));
    });

    test('un échec de transmission (réseau) n\'empêche pas l\'import de '
        'réussir — la donnée locale reste acquise', () async {
      tourRemoteSink.shouldThrow = true;

      final report = await engine.import(
        format: ImportFormat.pdf,
        source: _sourceFactice,
        preparateurId: 'prep-1',
        importedByUserId: 'admin-1',
      );

      expect(report.succes, isTrue);
      final tour = await tourRepository.findById(report.tourId!);
      expect(tour, isNotNull);
      expect(tour!.estTeleChargeeLocalement, isTrue);
    });
  });
}
