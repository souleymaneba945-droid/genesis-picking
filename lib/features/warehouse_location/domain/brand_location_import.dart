import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';

/// Levée quand un fichier d'import marque/emplacement ne peut pas être
/// lu ou n'a pas la structure attendue — même principe que
/// `ImportStructureException` du module `import/` (Module 3), mais
/// gardée locale à ce module plutôt que partagée : les deux imports
/// (tournée vs marque/emplacement) n'ont aucune règle métier en commun,
/// seulement une ressemblance de mécanique (fichier → lignes).
class BrandLocationImportException implements Exception {
  const BrandLocationImportException(this.message);
  final String message;
}

/// Statut d'une ligne d'import, déterminé par comparaison avec les
/// correspondances déjà enregistrées (Modernisation visuelle, 13/09/2026,
/// maquette v0.dev `brand-locations-screen.tsx`) — jamais par le fichier
/// lui-même, qui ne sait rien de l'état actuel de l'app.
enum BrandLocationImportStatus { nouveau, miseAJour, erreur }

/// Une ligne lue du fichier, déjà classée. [marque]/[emplacement] peuvent
/// être vides quand [statut] est [BrandLocationImportStatus.erreur].
class BrandLocationImportRow {
  const BrandLocationImportRow({
    required this.marque,
    required this.emplacement,
    required this.statut,
    this.message,
  });

  final String marque;
  final String emplacement;
  final BrandLocationImportStatus statut;

  /// Raison de l'erreur, uniquement quand [statut] est
  /// [BrandLocationImportStatus.erreur] — jamais affiché pour les deux
  /// autres statuts.
  final String? message;
}

/// Lit un fichier `.csv` ou `.xlsx` et produit une ligne par
/// marque/emplacement trouvé, déjà classée par comparaison avec
/// [existants] (Module 5 v2, Rubrique 2 — import en masse, jamais mélangé
/// avec l'emplacement de picking issu du PDF, voir `MODULE_5_V2.md`).
///
/// Reconnaissance de colonnes par alias insensible à la casse, même
/// principe que `CsvParser`/`ExcelParser` du module `import/` (Module 3) —
/// délibérément dupliqué plutôt que partagé : les deux modules n'ont
/// aucune règle métier commune, seulement une mécanique similaire.
List<BrandLocationImportRow> parseBrandLocationImportFile({
  required Uint8List bytes,
  required String fileName,
  required List<BrandWarehouseLocation> existants,
}) {
  final extension = fileName.split('.').last.toLowerCase();
  final List<List<String>> rows = switch (extension) {
    'csv' => _lireCsv(bytes, fileName),
    'xlsx' => _lireExcel(bytes, fileName),
    _ => throw BrandLocationImportException(
        'Format non pris en charge : "$fileName" (seuls .csv et .xlsx le sont).',
      ),
  };

  if (rows.isEmpty) {
    throw BrandLocationImportException(
      'Le fichier "$fileName" ne contient aucune ligne exploitable.',
    );
  }

  final header = rows.first.map((c) => c.trim().toLowerCase()).toList();

  int? indexOf(List<String> aliases) {
    for (final alias in aliases) {
      final index = header.indexOf(alias);
      if (index != -1) return index;
    }
    return null;
  }

  final iMarque = indexOf(['marque', 'brand', 'marques']);
  final iEmplacement = indexOf(['emplacement', 'location', 'entrepot', 'entrepôt']);

  if (iMarque == null || iEmplacement == null) {
    throw const BrandLocationImportException(
      'Colonnes obligatoires introuvables dans l\'en-tête '
      '(attendu : Marque, Emplacement).',
    );
  }

  final existantesParNomMinuscule = {
    for (final e in existants) e.marque.toLowerCase(): e,
  };

  final resultats = <BrandLocationImportRow>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.every((cell) => cell.trim().isEmpty)) continue; // ligne vide

    String cellAt(int index) => index < row.length ? row[index].trim() : '';
    final marque = cellAt(iMarque);
    final emplacement = cellAt(iEmplacement);

    if (marque.isEmpty || emplacement.isEmpty) {
      resultats.add(
        BrandLocationImportRow(
          marque: marque,
          emplacement: emplacement,
          statut: BrandLocationImportStatus.erreur,
          message: 'Marque ou emplacement manquant',
        ),
      );
      continue;
    }

    final existeDeja = existantesParNomMinuscule.containsKey(marque.toLowerCase());
    resultats.add(
      BrandLocationImportRow(
        marque: marque,
        emplacement: emplacement,
        statut: existeDeja
            ? BrandLocationImportStatus.miseAJour
            : BrandLocationImportStatus.nouveau,
      ),
    );
  }

  return resultats;
}

List<List<String>> _lireCsv(Uint8List bytes, String fileName) {
  try {
    final content = utf8.decode(bytes);
    final delimiteur = _detecterDelimiteur(content);
    final rows = CsvToListConverter(eol: '\n', fieldDelimiter: delimiteur).convert(content);
    return [
      for (final row in rows) [for (final cell in row) cell.toString()],
    ];
  } catch (_) {
    throw BrandLocationImportException(
      'Le fichier "$fileName" n\'a pas pu être lu comme un CSV.',
    );
  }
}

/// Un export "CSV" français utilise très souvent le point-virgule (Excel
/// régional FR), pas la virgule — détecté sur la première ligne plutôt
/// qu'imposé, pour rester compatible avec les deux (Modernisation
/// visuelle, 13/09/2026, même besoin que `parseCsv` de la maquette
/// source v0.dev, qui reconnaît `;`, `,` et la tabulation).
String _detecterDelimiteur(String content) {
  final premiereLigne = content.split(RegExp(r'\r?\n')).first;
  final compte = (String sep) => premiereLigne.split(sep).length - 1;
  final candidats = {';': compte(';'), ',': compte(','), '\t': compte('\t')};
  var meilleur = ',';
  var meilleurCompte = 0;
  candidats.forEach((sep, n) {
    if (n > meilleurCompte) {
      meilleur = sep;
      meilleurCompte = n;
    }
  });
  return meilleur;
}

List<List<String>> _lireExcel(Uint8List bytes, String fileName) {
  final Excel workbook;
  try {
    workbook = Excel.decodeBytes(bytes);
  } catch (_) {
    throw BrandLocationImportException(
      'Le fichier "$fileName" n\'a pas pu être lu comme un classeur Excel.',
    );
  }
  if (workbook.tables.isEmpty) {
    throw BrandLocationImportException(
      'Le classeur "$fileName" ne contient aucune feuille.',
    );
  }
  final sheet = workbook.tables.values.first;
  return [
    for (final row in sheet.rows)
      [for (final cell in row) (cell?.value?.toString() ?? '')],
  ];
}
