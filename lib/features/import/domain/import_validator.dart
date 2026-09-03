import 'package:genesis_picking/features/import/data/import_report.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';

/// Valide le contenu extrait d'une picking list, indépendamment de son
/// format d'origine (Directive : "Vérifier tournée valide, nombre de
/// produits, images présentes, emplacements, quantités").
///
/// Ne lève jamais d'exception : produit toujours une liste d'[ImportIssue],
/// que ce soit des erreurs bloquantes ou de simples avertissements.
///
/// Règles (choix corrigé après calibrage sur un vrai fichier
/// myFulfillment) :
/// - Numéro de tournée manquant, ou aucun produit → erreur bloquante au
///   niveau de la tournée entière.
/// - Nom ou quantité manquant/invalide sur UN produit → erreur bloquante :
///   sans ça, impossible de savoir quoi préparer ou en quelle quantité.
/// - Emplacement manquant → avertissement uniquement. Un vrai fichier
///   exporté par myFulfillment montre que l'emplacement est réellement
///   absent pour une partie des produits (pas encore rangés dans l'ERP) :
///   bloquer l'import à cause de ça rendrait impossible l'import de
///   picking lists réelles. Le préparateur peut chercher le produit par
///   son nom, l'emplacement s'ajoutera plus tard dans l'ERP.
/// - Image manquante → avertissement uniquement : le picking reste
///   possible sans photo (Document UX/UI : l'image aide, mais
///   emplacement + nom + quantité suffisent à opérer).
class ImportValidator {
  List<ImportIssue> validate(ParsedTournee tournee) {
    final issues = <ImportIssue>[];

    if (tournee.numeroTournee == null || tournee.numeroTournee!.trim().isEmpty) {
      issues.add(
        const ImportIssue(
          severity: ImportIssueSeverity.erreur,
          message: 'Numéro de tournée introuvable dans la source.',
        ),
      );
    }

    if (tournee.produits.isEmpty) {
      issues.add(
        const ImportIssue(
          severity: ImportIssueSeverity.erreur,
          message: 'Aucun produit détecté dans la source.',
        ),
      );
      return issues; // Rien d'autre à valider sans produit.
    }

    for (final produit in tournee.produits) {
      if (produit.nom == null || produit.nom!.trim().isEmpty) {
        issues.add(
          ImportIssue(
            severity: ImportIssueSeverity.erreur,
            message: 'Nom de produit manquant.',
            ligneSource: produit.ligneSource,
          ),
        );
      }

      if (produit.emplacement == null || produit.emplacement!.trim().isEmpty) {
        issues.add(
          ImportIssue(
            severity: ImportIssueSeverity.avertissement,
            message:
                'Emplacement non renseigné pour '
                '"${produit.nom ?? 'produit sans nom'}" — '
                'le préparateur devra le chercher par son nom.',
            ligneSource: produit.ligneSource,
          ),
        );
      }

      if (produit.quantiteDemandee == null || produit.quantiteDemandee! <= 0) {
        issues.add(
          ImportIssue(
            severity: ImportIssueSeverity.erreur,
            message:
                'Quantité manquante ou invalide pour '
                '"${produit.nom ?? 'produit sans nom'}".',
            ligneSource: produit.ligneSource,
          ),
        );
      }

      if (produit.imageUrl == null || produit.imageUrl!.trim().isEmpty) {
        issues.add(
          ImportIssue(
            severity: ImportIssueSeverity.avertissement,
            message:
                'Image absente pour "${produit.nom ?? 'produit sans nom'}" '
                '— le picking reste possible.',
            ligneSource: produit.ligneSource,
          ),
        );
      }
    }

    return issues;
  }
}
