import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';

/// Erreur de structure levée par un [ImportParser] lorsque la source ne
/// correspond pas du tout au format attendu (fichier corrompu, vide, ou
/// dont la structure ne peut pas du tout être interprétée).
///
/// Distincte des champs manquants sur un produit précis (gérés par
/// `ImportValidator`, qui produit des avertissements/erreurs par ligne
/// sans jamais lever d'exception) : ceci signale que le PARSING lui-même
/// a échoué, avant même d'avoir une structure à valider.
class ImportStructureException implements Exception {
  const ImportStructureException(this.message);
  final String message;
}

/// Contrat commun à tous les analyseurs de format.
///
/// Chaque implémentation ne fait qu'UNE chose : transformer une source
/// brute en [ParsedTournee]. Elle ne valide rien (voir
/// `ImportValidator`), ne persiste rien (voir `ImportEngine`), et ne
/// gère aucun historique. C'est ce qui permet d'ajouter un nouveau
/// format sans toucher au reste du moteur.
///
/// Ne doit JAMAIS planter l'application (Directive : "Ne jamais
/// planter") : toute erreur d'analyse doit être levée sous forme
/// d'[ImportStructureException], que `ImportEngine` capture et transforme
/// en rapport d'échec — jamais une exception non gérée.
abstract interface class ImportParser {
  ImportFormat get format;

  /// [onProgress], si fourni, est appelé au fur et à mesure de l'analyse
  /// avec (nombre de produits déjà traités, total) — pour qu'un écran
  /// d'import puisse afficher une progression réelle sur une source
  /// volumineuse plutôt qu'un simple indicateur "ça charge". Purement
  /// informatif : ignoré sans risque par tout analyseur assez rapide pour
  /// ne pas en avoir besoin (CSV, Excel, JSON — seul [PdfParser] l'utilise
  /// réellement, voir sa docstring).
  Future<ParsedTournee> parse(
    ImportSource source, {
    void Function(int done, int total)? onProgress,
  });
}
