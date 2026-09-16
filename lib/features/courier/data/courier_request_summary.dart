import 'package:genesis_picking/features/courier/data/courier_request.dart';

/// Une demande de la liste des missions d'un coursier (Refonte —
/// regroupement par préparateur), enrichie du nom du préparateur qui l'a
/// envoyée ET du produit concerné (nom, description/SKU, photo) — même
/// principe que [CourierRequestDetailView], pour que la liste affiche
/// exactement la même identification produit que la liste de picking du
/// préparateur, jamais une présentation appauvrie.
class CourierRequestSummary {
  const CourierRequestSummary({
    required this.request,
    required this.preparateurNom,
    required this.produitNom,
    this.produitDescription,
    this.produitImageUrl,
  });

  final CourierRequest request;
  final String preparateurNom;
  final String produitNom;
  final String? produitDescription;
  final String? produitImageUrl;
}

/// Regroupement de plusieurs [CourierRequestSummary] portant sur le MÊME
/// produit (Module 5 v2, Rubrique 1) — quand deux préparateurs différents
/// signalent le même produit introuvable, le coursier les voit comme une
/// seule entrée plutôt que deux demandes séparées à traiter en double.
class MergedCourierRequest {
  const MergedCourierRequest({
    required this.cle,
    required this.produitNom,
    required this.requests,
    this.produitDescription,
    this.produitImageUrl,
  });

  /// Clé de regroupement — jamais affichée, seulement utilisée pour
  /// distinguer les groupes entre eux (ex. dans un `ListView` par clé).
  final String cle;

  final String produitNom;
  final String? produitDescription;
  final String? produitImageUrl;

  /// Toujours au moins un élément.
  final List<CourierRequestSummary> requests;

  List<String> get requestIds => [for (final r in requests) r.request.id];
}

/// Regroupe des résumés déjà filtrés par le même onglet (ouvertes OU
/// closes — jamais un mélange des deux, voir `CourierRequestsTab`) par
/// produit réellement identique : la référence exacte (Module 5 v2,
/// Rubrique 1 — [CourierRequestSummary.produitDescription], ex.
/// `"234187 - 8800256119660"`), JAMAIS le nom (trop de variations
/// d'écriture possibles d'une tournée à l'autre).
///
/// Une demande sans référence (absente ou vide) n'est JAMAIS fusionnée
/// avec une autre, y compris une autre demande elle aussi sans référence
/// — chacune reste son propre groupe (clé = l'id de sa propre demande),
/// pour ne jamais fusionner à l'aveugle deux produits qu'on ne sait pas
/// vraiment reconnaître comme identiques.
List<MergedCourierRequest> groupCourierRequestsByProduct(
  List<CourierRequestSummary> summaries,
) {
  final groupes = <String, List<CourierRequestSummary>>{};
  final ordre = <String>[];
  for (final s in summaries) {
    final ref = s.produitDescription;
    final cle = (ref != null && ref.isNotEmpty)
        ? 'ref:$ref'
        : 'id:${s.request.id}';
    if (!groupes.containsKey(cle)) ordre.add(cle);
    groupes.putIfAbsent(cle, () => []).add(s);
  }
  return [
    for (final cle in ordre)
      MergedCourierRequest(
        cle: cle,
        produitNom: groupes[cle]!.first.produitNom,
        produitDescription: groupes[cle]!.first.produitDescription,
        produitImageUrl: groupes[cle]!.first.produitImageUrl,
        requests: groupes[cle]!,
      ),
  ];
}
