import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/picking_repository.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

import '../tours/fake_tour_repository.dart';

/// Implémentation en mémoire de [PickingRepository], utilisée uniquement
/// par les tests unitaires. Reproduit la même garantie logique que
/// [DriftPickingRepository] (mise à jour du produit ET de la progression
/// de la tournée ensemble), sans dépendre de Drift.
class FakePickingRepository implements PickingRepository {
  FakePickingRepository(this._tourRepository);

  final FakeTourRepository _tourRepository;
  final Map<String, List<PickingProduct>> _products = {};

  /// Prépare les produits d'une tournée pour le test (équivalent de
  /// `ensureStatusesInitialized` + import des lignes en Module 3).
  void seed(String tourId, List<PickingProduct> produits) {
    _products[tourId] = List.of(produits);
  }

  @override
  Future<List<PickingProduct>> loadProducts(String tourId) async {
    return List.unmodifiable(_products[tourId] ?? const []);
  }

  @override
  Future<void> applyValidation({
    required String tourId,
    required String productLineId,
    required ProductState etat,
    int? quantiteCollectee,
  }) async {
    final list = _products[tourId];
    if (list == null) return;
    final index = list.indexWhere((p) => p.id == productLineId);
    if (index == -1) return;

    list[index] = list[index].copyWith(
      etat: etat,
      quantiteCollectee: quantiteCollectee,
    );

    final traites = list.where((p) => p.etat.estTraite).length;
    await _tourRepository.updateProgress(
      tourId: tourId,
      produitsTraites: traites,
    );
  }
}
