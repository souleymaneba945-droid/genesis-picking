import 'package:genesis_picking/features/courier/data/courier_request.dart';

/// Vue enrichie d'une demande, pour l'écran de traitement du coursier
/// (Directive, "Traitement") : photo, nom, description (SKU/code-barres),
/// quantité, emplacement, préparateur demandeur — en plus des champs
/// bruts de [CourierRequest].
///
/// [produitDescription] doit toujours être renseigné dès que le produit en
/// a une (voir `PickingProduct.description`) : c'est la même référence
/// affichée au préparateur sur la liste de picking, et le coursier s'en
/// sert pour identifier le produit exactement de la même façon — jamais
/// une présentation appauvrie par rapport au picking.
class CourierRequestDetailView {
  const CourierRequestDetailView({
    required this.request,
    required this.produitNom,
    required this.preparateurNom,
    this.produitDescription,
    this.produitImageUrl,
  });

  final CourierRequest request;
  final String produitNom;
  final String? produitDescription;
  final String? produitImageUrl;
  final String preparateurNom;
}
