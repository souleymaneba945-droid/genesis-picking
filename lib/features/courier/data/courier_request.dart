import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Une demande envoyée par un préparateur à un coursier pour un produit
/// introuvable. Contient exactement les champs exigés par la Directive
/// Module 5.
class CourierRequest {
  const CourierRequest({
    required this.id,
    required this.preparateurId,
    required this.coursierId,
    required this.tourId,
    required this.productLineId,
    required this.quantiteDemandee,
    required this.emplacement,
    required this.dateCreation,
    required this.etat,
    this.resultat,
    this.dateAcceptation,
    this.dateTraitement,
    this.dateCloture,
    this.produitNom,
    this.produitDescription,
    this.produitImageUrl,
  });

  final String id;
  final String preparateurId;
  final String coursierId;
  final String tourId;
  final String productLineId;
  final int quantiteDemandee;
  final String emplacement;
  final DateTime dateCreation;
  final CourierRequestStatus etat;
  final CourierRequestResult? resultat;
  final DateTime? dateAcceptation;
  final DateTime? dateTraitement;
  final DateTime? dateCloture;

  /// Instantané du produit pris au moment de la création (voir
  /// `CourierRequestsTable` pour le pourquoi) — `null` sur les demandes
  /// créées avant l'introduction de ces colonnes, auquel cas
  /// [CourierService] retombe sur la jointure locale vers
  /// `ProductRepository`.
  final String? produitNom;
  final String? produitDescription;
  final String? produitImageUrl;

  /// Une demande compte dans la charge de travail d'un coursier tant
  /// qu'elle n'a pas atteint un état final.
  bool get estOuverte =>
      etat != CourierRequestStatus.traitee &&
      etat != CourierRequestStatus.terminee;

  CourierRequest copyWith({
    CourierRequestStatus? etat,
    CourierRequestResult? resultat,
    DateTime? dateAcceptation,
    DateTime? dateTraitement,
    DateTime? dateCloture,
  }) {
    return CourierRequest(
      id: id,
      preparateurId: preparateurId,
      coursierId: coursierId,
      tourId: tourId,
      productLineId: productLineId,
      quantiteDemandee: quantiteDemandee,
      emplacement: emplacement,
      dateCreation: dateCreation,
      etat: etat ?? this.etat,
      resultat: resultat ?? this.resultat,
      dateAcceptation: dateAcceptation ?? this.dateAcceptation,
      dateTraitement: dateTraitement ?? this.dateTraitement,
      dateCloture: dateCloture ?? this.dateCloture,
      produitNom: produitNom,
      produitDescription: produitDescription,
      produitImageUrl: produitImageUrl,
    );
  }
}
