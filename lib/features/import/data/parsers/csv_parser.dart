import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';

/// Analyseur CSV.
///
/// Attend une ligne d'en-tête suivie d'une ligne par produit, avec le
/// numéro de tournée répété sur chaque ligne (format plat, le plus
/// courant en export ERP). Colonnes reconnues, insensibles à la casse
/// (`numero_tournee`/`tournee`, `nom`/`produit`, `description`,
/// `image`/`image_url`, `quantite`/`qte`, `emplacement`/`rayon`) — à
/// ajuster dès qu'un vrai export CSV du logiciel de gestion sera
/// disponible (voir MODULE_IMPORT.md).
class CsvParser implements ImportParser {
  @override
  ImportFormat get format => ImportFormat.csv;

  @override
  Future<ParsedTournee> parse(
    ImportSource source, {
    void Function(int done, int total)? onProgress,
  }) async {
    final List<List<dynamic>> rows;
    try {
      final content = utf8.decode(source.bytes);
      rows = const CsvToListConverter(eol: '\n').convert(content);
    } catch (error) {
      throw ImportStructureException(
        'Le fichier "${source.fileName}" n\'a pas pu être lu comme un CSV.',
      );
    }

    if (rows.isEmpty) {
      throw const ImportStructureException('Le fichier CSV est vide.');
    }

    final header = rows.first
        .map((cell) => cell.toString().trim().toLowerCase())
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
        'Colonnes obligatoires introuvables dans l\'en-tête CSV '
        '(nom, quantité, emplacement).',
      );
    }

    String? numeroTournee;
    final produits = <ParsedProduit>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row.first.toString().isEmpty)) {
        continue; // Ligne vide en fin de fichier — ignorée silencieusement.
      }

      String? cell(int? index) {
        if (index == null || index >= row.length) return null;
        final value = row[index]?.toString().trim();
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
