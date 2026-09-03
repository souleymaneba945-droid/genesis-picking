import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Contrat abstrait d'accès aux produits d'une tournée, avec leur état de
/// collecte. [PickingService] ne dépend que de cette interface (via
/// [PickingRepository], voir plus bas), jamais de Drift directement.
abstract interface class ProductRepository {
  /// Crée un état "À récupérer" pour chaque ligne produit de la tournée
  /// qui n'en a pas encore — idempotent, sans effet si déjà fait. Appelé
  /// systématiquement à l'ouverture d'une tournée (Directive : "Lorsqu'une
  /// tournée est ouverte, charger automatiquement... leur état").
  Future<void> ensureStatusesInitialized(String tourId);

  /// Renvoie tous les produits d'une tournée, triés par ordre d'origine.
  Future<List<PickingProduct>> listForTour(String tourId);

  Future<PickingProduct?> findById(String productLineId);

  Future<void> updateState({
    required String productLineId,
    required ProductState etat,
    int? quantiteCollectee,
  });
}
