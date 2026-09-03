import 'package:genesis_picking/features/import/data/import_format.dart';

enum ImportIssueSeverity { avertissement, erreur }

/// Un élément signalé pendant la validation — jamais une exception,
/// toujours une donnée du rapport (Directive : "Si un élément est
/// absent, le signaler. Ne jamais planter.").
class ImportIssue {
  const ImportIssue({
    required this.severity,
    required this.message,
    this.ligneSource,
  });

  final ImportIssueSeverity severity;
  final String message;
  final int? ligneSource;

  bool get estBloquant => severity == ImportIssueSeverity.erreur;
}

/// Rapport produit après chaque tentative d'import (Directive :
/// "Produire un rapport d'import").
class ImportReport {
  const ImportReport({
    required this.succes,
    required this.format,
    required this.date,
    required this.importePar,
    required this.duree,
    required this.nombreProduits,
    required this.issues,
    this.tourId,
    this.numeroTournee,
    this.dejaImportee = false,
  });

  final bool succes;
  final ImportFormat format;
  final DateTime date;
  final String importePar;
  final Duration duree;
  final int nombreProduits;
  final List<ImportIssue> issues;
  final String? tourId;
  final String? numeroTournee;

  /// Vrai si cet import correspondait à une tournée déjà importée
  /// (même numéro) — l'import n'a rien dupliqué (Directive : "doublons").
  final bool dejaImportee;

  List<ImportIssue> get erreurs =>
      issues.where((i) => i.severity == ImportIssueSeverity.erreur).toList();

  List<ImportIssue> get avertissements => issues
      .where((i) => i.severity == ImportIssueSeverity.avertissement)
      .toList();
}
