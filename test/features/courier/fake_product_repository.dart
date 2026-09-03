import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_repository.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Implémentation en mémoire de [ProductRepository], utilisée par les
/// tests du module Coursier pour fournir les informations d'affichage
/// (nom, image) sans dépendre de Drift.
class FakeProductRepository implements ProductRepository {
  final Map<String, PickingProduct> _products = {};

  void seed(PickingProduct product) {
    _products[product.id] = product;
  }

  @override
  Future<void> ensureStatusesInitialized(String tourId) async {}

  @override
  Future<List<PickingProduct>> listForTour(String tourId) async {
    return _products.values.where((p) => p.tourId == tourId).toList();
  }

  @override
  Future<PickingProduct?> findById(String productLineId) async {
    return _products[productLineId];
  }

  @override
  Future<void> updateState({
    required String productLineId,
    required ProductState etat,
    int? quantiteCollectee,
  }) async {
    final existing = _products[productLineId];
    if (existing == null) return;
    _products[productLineId] = existing.copyWith(
      etat: etat,
      quantiteCollectee: quantiteCollectee,
    );
  }
}
