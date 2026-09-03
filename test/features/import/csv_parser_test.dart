import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsers/csv_parser.dart';

ImportSource _source(String content) {
  return ImportSource(
    bytes: Uint8List.fromList(utf8.encode(content)),
    fileName: 'test.csv',
  );
}

void main() {
  final parser = CsvParser();

  test('analyse un CSV valide avec toutes les colonnes', () async {
    const csv =
        'numero_tournee,nom,description,image,quantite,emplacement\n'
        'T-2026-0001,Savon,Savon doux,http://x/img.png,3,Rayon A1\n'
        'T-2026-0001,Creme,,,1,Rayon B2\n';

    final result = await parser.parse(_source(csv));

    expect(result.numeroTournee, 'T-2026-0001');
    expect(result.produits, hasLength(2));
    expect(result.produits[0].nom, 'Savon');
    expect(result.produits[0].quantiteDemandee, 3);
    expect(result.produits[1].imageUrl, isNull);
  });

  test('reconnaît les alias de colonnes courants', () async {
    const csv = 'tournee,produit,qte,rayon\nT-1,Savon,2,A1\n';
    final result = await parser.parse(_source(csv));
    expect(result.numeroTournee, 'T-1');
    expect(result.produits.single.nom, 'Savon');
    expect(result.produits.single.emplacement, 'A1');
  });

  test('fichier incomplet : colonnes obligatoires manquantes → erreur de structure', () async {
    const csv = 'numero_tournee,description\nT-1,rien\n';
    expect(
      () => parser.parse(_source(csv)),
      throwsA(isA<ImportStructureException>()),
    );
  });

  test('fichier vide → erreur de structure, jamais un crash', () async {
    expect(
      () => parser.parse(_source('')),
      throwsA(isA<ImportStructureException>()),
    );
  });

  test('gros fichier : plusieurs centaines de lignes traitées', () async {
    final buffer = StringBuffer('numero_tournee,nom,quantite,emplacement\n');
    for (var i = 0; i < 400; i++) {
      buffer.writeln('T-GROS,Produit $i,1,Rayon $i');
    }
    final result = await parser.parse(_source(buffer.toString()));
    expect(result.produits, hasLength(400));
  });
}
