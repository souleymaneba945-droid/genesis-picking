/// États possibles d'un produit pendant la collecte.
///
/// Reprend EXACTEMENT les cinq états de la Directive Module 4. Aucun
/// autre état ne doit être ajouté sans repasser par cette directive.
///
/// [envoyeAuCoursier] est défini ici mais n'est pas encore atteignable
/// dans ce module : la Directive précise "l'écran de choix du coursier
/// ne sera développé qu'au module suivant" — ce module se contente de
/// créer le point d'entrée ([ProductState.introuvable]), qui restera
/// l'état final tant que le Module 5 n'aura pas ajouté le choix du
/// coursier et la transition vers [envoyeAuCoursier].
enum ProductState {
  aRecuperer,
  collecte,
  partiellementCollecte,
  introuvable,
  envoyeAuCoursier,
}

/// Un produit est considéré "traité" (compte dans la progression) dès
/// qu'il a quitté l'état initial — conforme au PRD (chapitre 4.2) qui ne
/// définit [aRecuperer] que comme point de départ.
extension ProductStateProgress on ProductState {
  bool get estTraite => this != ProductState.aRecuperer;
}
