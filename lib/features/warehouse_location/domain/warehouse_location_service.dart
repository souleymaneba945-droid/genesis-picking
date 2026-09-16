import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location_repository.dart';

/// Détermine l'emplacement entrepôt d'un produit à partir de son nom
/// (Module 5 v2, Rubrique 2).
///
/// Reconnaissance de marque = le nom du produit COMMENCE PAR une marque
/// connue (insensible à la casse) — jamais une recherche n'importe où
/// dans le nom, pour éviter les fausses correspondances (décision
/// utilisateur du 08/09/2026). Si plusieurs marques connues correspondent
/// (cas rare, ex. une marque préfixe d'une autre), la plus longue —
/// donc la plus spécifique — l'emporte.
class WarehouseLocationService {
  WarehouseLocationService(this._repository);

  final BrandWarehouseLocationRepository _repository;

  /// `null` si aucune marque connue ne correspond — l'appelant affiche
  /// alors "Emplacement entrepôt non renseigné" (décision utilisateur du
  /// 08/09/2026), jamais un champ vide silencieux.
  Future<String?> findEmplacement(String produitNom) async {
    final marques = await _repository.listAll();
    return matchMarque(produitNom, marques)?.emplacement;
  }

  /// Version "en lot" de la correspondance marque — même règle que
  /// [findEmplacement], mais prend la liste des marques déjà chargée en
  /// paramètre plutôt que de la recharger (Modernisation, 16/09/2026,
  /// statistiques par marque des demandes coursier) : traiter des
  /// centaines de demandes une par une via [findEmplacement] rechargerait
  /// la liste à chaque fois — un simple appel statique, sans état, évite
  /// ce N+1 sans dupliquer la règle de correspondance.
  static BrandWarehouseLocation? matchMarque(
    String produitNom,
    List<BrandWarehouseLocation> marques,
  ) {
    final nomNormalise = produitNom.toLowerCase();
    BrandWarehouseLocation? meilleure;
    var meilleureLongueur = -1;
    for (final marque in marques) {
      final marqueNormalisee = marque.marque.toLowerCase();
      if (nomNormalise.startsWith(marqueNormalisee) &&
          marqueNormalisee.length > meilleureLongueur) {
        meilleure = marque;
        meilleureLongueur = marqueNormalisee.length;
      }
    }
    return meilleure;
  }
}
