import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Représentation d'une tournée, indépendante de la technologie de
/// stockage. Ne contient volontairement aucune liste de produits — la
/// séparation stricte données/logique/interface exigée par la Directive
/// Module 3 s'applique aussi aux produits, gérés par le Module 4
/// (`PickingProduct`, `TourProductLinesTable`).
class Tour {
  const Tour({
    required this.id,
    required this.numeroTournee,
    required this.preparateurId,
    required this.dateCreation,
    required this.statut,
    required this.etatSynchronisation,
    required this.nombreTotalProduits,
    required this.produitsTraites,
    this.dateTelechargement,
    this.dateSynchronisation,
  });

  final String id;
  final String numeroTournee;
  final String preparateurId;
  final DateTime dateCreation;
  final DateTime? dateTelechargement;
  final TourStatus statut;
  final TourSyncState etatSynchronisation;
  final int nombreTotalProduits;
  final int produitsTraites;
  final DateTime? dateSynchronisation;

  bool get estTeleChargeeLocalement => dateTelechargement != null;

  Tour copyWith({
    DateTime? dateTelechargement,
    TourStatus? statut,
    TourSyncState? etatSynchronisation,
    int? produitsTraites,
    DateTime? dateSynchronisation,
  }) {
    return Tour(
      id: id,
      numeroTournee: numeroTournee,
      preparateurId: preparateurId,
      dateCreation: dateCreation,
      dateTelechargement: dateTelechargement ?? this.dateTelechargement,
      statut: statut ?? this.statut,
      etatSynchronisation: etatSynchronisation ?? this.etatSynchronisation,
      nombreTotalProduits: nombreTotalProduits,
      produitsTraites: produitsTraites ?? this.produitsTraites,
      dateSynchronisation: dateSynchronisation ?? this.dateSynchronisation,
    );
  }
}
