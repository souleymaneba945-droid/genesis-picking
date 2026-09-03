import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Un produit tel que présenté à l'écran de picking : combine les
/// données brutes de la tournée (Module 3) et l'état de collecte propre
/// à ce module. Ni [ProductRepository] ni [PickingRepository] n'exposent
/// jamais les deux sources séparément à la couche présentation — c'est
/// toujours ce modèle unique qui circule.
class PickingProduct {
  const PickingProduct({
    required this.id,
    required this.tourId,
    required this.ordre,
    required this.nom,
    required this.quantiteDemandee,
    required this.emplacement,
    required this.etat,
    this.description,
    this.imageUrl,
    this.quantiteCollectee,
  });

  final String id;
  final String tourId;
  final int ordre;
  final String nom;
  final String? description;
  final String? imageUrl;
  final int quantiteDemandee;
  final String emplacement;
  final ProductState etat;
  final int? quantiteCollectee;

  PickingProduct copyWith({ProductState? etat, int? quantiteCollectee}) {
    return PickingProduct(
      id: id,
      tourId: tourId,
      ordre: ordre,
      nom: nom,
      description: description,
      imageUrl: imageUrl,
      quantiteDemandee: quantiteDemandee,
      emplacement: emplacement,
      etat: etat ?? this.etat,
      quantiteCollectee: quantiteCollectee ?? this.quantiteCollectee,
    );
  }
}
