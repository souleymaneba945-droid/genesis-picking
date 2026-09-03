/// Formats d'import pris en charge par le moteur.
///
/// Ajouter un format = ajouter une valeur ici + un [ImportParser] dans
/// `parsers/` + l'enregistrer dans `ImportEngine` — jamais modifier la
/// logique de validation, de rapport ou d'historique, qui sont
/// indépendantes du format d'origine.
enum ImportFormat { pdf, excel, csv, json, api }

/// Libellés d'affichage (Administrateur — écran d'import).
extension ImportFormatLabel on ImportFormat {
  String get libelle => switch (this) {
    ImportFormat.pdf => 'PDF',
    ImportFormat.excel => 'Excel (.xlsx)',
    ImportFormat.csv => 'CSV',
    ImportFormat.json => 'JSON',
    ImportFormat.api => 'API',
  };
}
