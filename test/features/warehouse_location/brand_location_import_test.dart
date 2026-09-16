import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/domain/brand_location_import.dart';

Uint8List _csv(String content) => Uint8List.fromList(utf8.encode(content));

void main() {
  group(
    'parseBrandLocationImportFile — Module 5 v2, Rubrique 2 (import en masse)',
    () {
      test('classe une marque inconnue comme "nouveau"', () {
        final rows = parseBrandLocationImportFile(
          bytes: _csv('Marque,Emplacement\nDove,Entrepôt A · Allée 3'),
          fileName: 'marques.csv',
          existants: const [],
        );

        expect(rows, hasLength(1));
        expect(rows.first.marque, 'Dove');
        expect(rows.first.emplacement, 'Entrepôt A · Allée 3');
        expect(rows.first.statut, BrandLocationImportStatus.nouveau);
      });

      test(
        'classe une marque déjà enregistrée comme "miseAJour" '
        '(comparaison insensible à la casse)',
        () {
          final rows = parseBrandLocationImportFile(
            bytes: _csv('Marque,Emplacement\ndove,Entrepôt B'),
            fileName: 'marques.csv',
            existants: const [
              BrandWarehouseLocation(id: '1', marque: 'Dove', emplacement: 'Ancien'),
            ],
          );

          expect(rows.first.statut, BrandLocationImportStatus.miseAJour);
        },
      );

      test('marque ou emplacement manquant → ligne en erreur, jamais fusionnée', () {
        final rows = parseBrandLocationImportFile(
          bytes: _csv('Marque,Emplacement\n,Entrepôt A\nAxe,'),
          fileName: 'marques.csv',
          existants: const [],
        );

        expect(rows, hasLength(2));
        expect(rows.every((r) => r.statut == BrandLocationImportStatus.erreur), isTrue);
        expect(rows.every((r) => r.message != null), isTrue);
      });

      test('ignore les lignes complètement vides en fin de fichier', () {
        final rows = parseBrandLocationImportFile(
          bytes: _csv('Marque,Emplacement\nDove,Entrepôt A\n\n'),
          fileName: 'marques.csv',
          existants: const [],
        );

        expect(rows, hasLength(1));
      });

      test('reconnaît le point-virgule comme séparateur', () {
        final rows = parseBrandLocationImportFile(
          bytes: _csv('Marque;Emplacement\nGarnier;Entrepôt C'),
          fileName: 'marques.csv',
          existants: const [],
        );

        expect(rows.first.marque, 'Garnier');
        expect(rows.first.emplacement, 'Entrepôt C');
      });

      test('en-tête sans colonne "Marque"/"Emplacement" reconnaissable → erreur explicite', () {
        expect(
          () => parseBrandLocationImportFile(
            bytes: _csv('Nom,Rayon\nDove,A3'),
            fileName: 'marques.csv',
            existants: const [],
          ),
          throwsA(isA<BrandLocationImportException>()),
        );
      });

      test('extension non prise en charge → erreur explicite, jamais un fichier mal lu', () {
        expect(
          () => parseBrandLocationImportFile(
            bytes: _csv('peu importe'),
            fileName: 'marques.pdf',
            existants: const [],
          ),
          throwsA(isA<BrandLocationImportException>()),
        );
      });

      test('fichier vide → erreur explicite', () {
        expect(
          () => parseBrandLocationImportFile(
            bytes: _csv(''),
            fileName: 'marques.csv',
            existants: const [],
          ),
          throwsA(isA<BrandLocationImportException>()),
        );
      });
    },
  );
}
