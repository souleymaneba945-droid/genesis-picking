import 'package:excel/excel.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';

/// Analyseur Excel (.xlsx).
///
/// Lit la PREMIÈRE feuille du classeur, même logique de colonnes que
/// `CsvParser` (en-tête + une ligne par produit). À ajuster dès qu'un
/// vrai export Excel du logiciel de gestion sera disponible.
class ExcelParser implements ImportParser {
  @override
  ImportFormat get format => ImportFormat.excel;

  @override
  Future<ParsedTournee> parse(
    ImportSource source, {
    void Function(int done, int total)? onProgress,
  }) async {
    final Excel workbook;
    try {
      workbook = Excel.decodeBytes(source.bytes);
    } catch (error) {
      throw ImportStructureException(
        'Le fichier "${source.fileName}" n\'a pas pu être lu comme un '
        'classeur Excel.',
      );
    }

    if (workbook.tables.isEmpty) {
      throw const ImportStructureException(
        'Le classeur Excel ne contient aucune feuille.',
      );
    }

    final sheet = workbook.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      throw const ImportStructureException('La feuille Excel est vide.');
    }

    final header = rows.first
        .map((cell) => (cell?.value?.toString() ?? '').trim().toLowerCase())
        .toList();

    int? indexOf(List<String> aliases) {
      for (final alias in aliases) {
        final index = header.indexOf(alias);
        if (index != -1) return index;
      }
      return null;
    }

    final iTournee = indexOf(['numero_tournee', 'tournee', 'numerotournee']);
    final iNom = indexOf(['nom', 'produit', 'nom_produit']);
    final iDescription = indexOf(['description']);
    final iImage = indexOf(['image', 'image_url', 'photo']);
    final iQuantite = indexOf(['quantite', 'qte', 'quantite_demandee']);
    final iEmplacement = indexOf(['emplacement', 'rayon', 'location']);

    if (iNom == null || iQuantite == null || iEmplacement == null) {
      throw const ImportStructureException(
        'Colonnes obligatoires introuvables dans l\'en-tête Excel '
        '(nom, quantité, emplacement).',
      );
    }

    String? numeroTournee;
    final produits = <ParsedProduit>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => (cell?.value?.toString() ?? '').trim().isEmpty)) {
        continue;
      }

      String? cell(int? index) {
        if (index == null || index >= row.length) return null;
        final value = row[index]?.value?.toString().trim();
        return (value == null || value.isEmpty) ? null : value;
      }

      numeroTournee ??= cell(iTournee);

      produits.add(
        ParsedProduit(
          ligneSource: i + 1,
          nom: cell(iNom),
          description: cell(iDescription),
          imageUrl: cell(iImage),
          emplacement: cell(iEmplacement),
          quantiteDemandee: int.tryParse(cell(iQuantite) ?? ''),
        ),
      );
    }

    return ParsedTournee(numeroTournee: numeroTournee, produits: produits);
  }
}
