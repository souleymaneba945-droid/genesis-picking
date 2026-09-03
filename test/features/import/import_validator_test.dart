import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/import/data/import_report.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';
import 'package:genesis_picking/features/import/domain/import_validator.dart';

void main() {
  final validator = ImportValidator();

  test('une tournée complète et valide ne produit aucune erreur bloquante', () {
    final issues = validator.validate(
      const ParsedTournee(
        numeroTournee: 'T-2026-0001',
        produits: [
          ParsedProduit(
            ligneSource: 1,
            nom: 'Savon',
            emplacement: 'Rayon A1',
            quantiteDemandee: 2,
            imageUrl: 'https://exemple.test/savon.png',
          ),
        ],
      ),
    );
    expect(issues.any((i) => i.estBloquant), isFalse);
  });

  test('numéro de tournée manquant → erreur bloquante', () {
    final issues = validator.validate(
      const ParsedTournee(
        produits: [
          ParsedProduit(
            ligneSource: 1,
            nom: 'Savon',
            emplacement: 'Rayon A1',
            quantiteDemandee: 2,
          ),
        ],
      ),
    );
    expect(issues.any((i) => i.estBloquant), isTrue);
  });

  test('aucun produit → erreur bloquante, sans autre vérification', () {
    final issues = validator.validate(
      const ParsedTournee(numeroTournee: 'T-2026-0001', produits: []),
    );
    expect(issues, hasLength(1));
    expect(issues.single.estBloquant, isTrue);
  });

  test('nom et quantité manquants → deux erreurs bloquantes ; emplacement manquant → avertissement', () {
    final issues = validator.validate(
      const ParsedTournee(
        numeroTournee: 'T-2026-0001',
        produits: [ParsedProduit(ligneSource: 1)],
      ),
    );
    final erreurs = issues.where((i) => i.estBloquant).toList();
    expect(erreurs, hasLength(2));
    final avertissements = issues
        .where((i) => i.severity == ImportIssueSeverity.avertissement)
        .toList();
    expect(
      avertissements.any((a) => a.message.contains('Emplacement')),
      isTrue,
    );
  });

  test('quantité négative ou nulle → erreur bloquante', () {
    final issues = validator.validate(
      const ParsedTournee(
        numeroTournee: 'T-2026-0001',
        produits: [
          ParsedProduit(
            ligneSource: 1,
            nom: 'Savon',
            emplacement: 'Rayon A1',
            quantiteDemandee: 0,
          ),
        ],
      ),
    );
    expect(issues.any((i) => i.estBloquant), isTrue);
  });

  test('image manquante → avertissement seulement, jamais bloquant', () {
    final issues = validator.validate(
      const ParsedTournee(
        numeroTournee: 'T-2026-0001',
        produits: [
          ParsedProduit(
            ligneSource: 1,
            nom: 'Savon',
            emplacement: 'Rayon A1',
            quantiteDemandee: 2,
          ),
        ],
      ),
    );
    expect(issues, hasLength(1));
    expect(issues.single.severity, ImportIssueSeverity.avertissement);
  });

  test('gros fichier : plusieurs centaines de produits valides sans erreur', () {
    final produits = List.generate(
      500,
      (i) => ParsedProduit(
        ligneSource: i + 1,
        nom: 'Produit $i',
        emplacement: 'Rayon $i',
        quantiteDemandee: 1,
        imageUrl: 'https://exemple.test/$i.png',
      ),
    );
    final issues = validator.validate(
      ParsedTournee(numeroTournee: 'T-2026-0002', produits: produits),
    );
    expect(issues, isEmpty);
  });
}
