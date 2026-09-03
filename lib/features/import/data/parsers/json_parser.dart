import 'dart:convert';

import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';

/// Analyseur JSON.
///
/// Format attendu (à ajuster dès qu'un vrai export JSON du logiciel de
/// gestion sera disponible — voir MODULE_IMPORT.md) :
/// ```json
/// {
///   "numeroTournee": "T-2026-0001",
///   "produits": [
///     {"nom": "...", "description": "...", "imageUrl": "...",
///      "quantite": 3, "emplacement": "Rayon A2"}
///   ]
/// }
/// ```
/// N'échoue (`ImportStructureException`) que si le contenu n'est pas du
/// JSON valide ou ne contient pas de tableau `produits` du tout — les
/// champs manquants sur un produit précis sont laissés à `null` pour que
/// `ImportValidator` les signale, jamais une exception ici.
class JsonParser implements ImportParser {
  @override
  ImportFormat get format => ImportFormat.json;

  @override
  Future<ParsedTournee> parse(
    ImportSource source, {
    void Function(int done, int total)? onProgress,
  }) async {
    final Map<String, dynamic> root;
    try {
      final decoded = utf8.decode(source.bytes);
      root = jsonDecode(decoded) as Map<String, dynamic>;
    } catch (error) {
      throw ImportStructureException(
        'Le fichier "${source.fileName}" n\'est pas un JSON valide.',
      );
    }

    final produitsBruts = root['produits'];
    if (produitsBruts is! List) {
      throw const ImportStructureException(
        'Aucun tableau "produits" trouvé dans le JSON.',
      );
    }

    final produits = <ParsedProduit>[];
    for (var i = 0; i < produitsBruts.length; i++) {
      final item = produitsBruts[i];
      if (item is! Map) {
        produits.add(ParsedProduit(ligneSource: i + 1));
        continue;
      }
      produits.add(
        ParsedProduit(
          ligneSource: i + 1,
          nom: item['nom'] as String?,
          description: item['description'] as String?,
          imageUrl: item['imageUrl'] as String?,
          emplacement: item['emplacement'] as String?,
          quantiteDemandee: _asInt(item['quantite']),
        ),
      );
    }

    return ParsedTournee(
      numeroTournee: root['numeroTournee'] as String?,
      produits: produits,
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
