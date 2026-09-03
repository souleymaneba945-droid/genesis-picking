import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsers/json_parser.dart';

ImportSource _source(String content) {
  return ImportSource(
    bytes: Uint8List.fromList(utf8.encode(content)),
    fileName: 'test.json',
  );
}

void main() {
  final parser = JsonParser();

  test('analyse un JSON valide', () async {
    const json = '''
    {
      "numeroTournee": "T-2026-0001",
      "produits": [
        {"nom": "Savon", "quantite": 3, "emplacement": "Rayon A1"}
      ]
    }
    ''';
    final result = await parser.parse(_source(json));
    expect(result.numeroTournee, 'T-2026-0001');
    expect(result.produits.single.nom, 'Savon');
    expect(result.produits.single.quantiteDemandee, 3);
  });

  test('JSON invalide → erreur de structure, jamais un crash', () async {
    expect(
      () => parser.parse(_source('{ceci nest pas du json')),
      throwsA(isA<ImportStructureException>()),
    );
  });

  test('champ "produits" absent → erreur de structure', () async {
    expect(
      () => parser.parse(_source('{"numeroTournee": "T-1"}')),
      throwsA(isA<ImportStructureException>()),
    );
  });

  test('produit incomplet : champs manquants laissés nuls, pas d\'exception', () async {
    const json = '{"numeroTournee": "T-1", "produits": [{"nom": "Savon"}]}';
    final result = await parser.parse(_source(json));
    expect(result.produits.single.nom, 'Savon');
    expect(result.produits.single.quantiteDemandee, isNull);
    expect(result.produits.single.emplacement, isNull);
  });
}
