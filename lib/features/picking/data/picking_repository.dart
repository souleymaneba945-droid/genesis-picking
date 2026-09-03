import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Contrat abstrait de l'opération centrale du moteur de picking :
/// appliquer une validation de produit de façon atomique avec la mise à
/// jour de la progression de la tournée.
///
/// Distinct de [ProductRepository] (CRUD pur sur les produits, sans
/// connaissance de la tournée) : [PickingRepository] est le seul endroit
/// qui touche à la fois l'état d'un produit et le compteur de
/// progression de sa tournée, dans une unique transaction — condition
/// nécessaire à la Directive ("aucune perte possible", "changement
/// instantané").
abstract interface class PickingRepository {
  /// Charge (en initialisant les états manquants si besoin) tous les
  /// produits d'une tournée, triés par ordre d'origine.
  Future<List<PickingProduct>> loadProducts(String tourId);

  /// Applique la validation d'un produit : met à jour son état ET
  /// recalcule/persiste la progression de la tournée, de façon atomique.
  Future<void> applyValidation({
    required String tourId,
    required String productLineId,
    required ProductState etat,
    int? quantiteCollectee,
  });
}
