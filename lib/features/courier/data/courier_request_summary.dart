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
