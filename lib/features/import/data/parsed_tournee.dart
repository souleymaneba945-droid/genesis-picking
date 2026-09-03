/// Un produit tel qu'extrait brut d'une picking list, AVANT validation.
///
/// Volontairement tout nullable : c'est le rôle d'`ImportValidator` de
/// décider ce qui est acceptable ou non, jamais celui du parser. Un
/// parser ne fait qu'extraire ce qu'il trouve, sans juger.
class ParsedProduit {
  const ParsedProduit({
    required this.ligneSource,
    this.nom,
    this.description,
    this.imageUrl,
    this.quantiteDemandee,
    this.emplacement,
  });

  /// Numéro de ligne ou de position dans la source d'origine, pour que
  /// le rapport d'import puisse désigner précisément un produit en
  /// erreur (Directive : "Si un élément est absent, le signaler").
  final int ligneSource;

  final String? nom;
  final String? description;
  final String? imageUrl;
  final int? quantiteDemandee;
  final String? emplacement;
}

/// Une tournée telle qu'extraite brute d'une source, AVANT validation.
class ParsedTournee {
  const ParsedTournee({
    required this.produits,
    this.numeroTournee,
  });

  final String? numeroTournee;
  final List<ParsedProduit> produits;
}
