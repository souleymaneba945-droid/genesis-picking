import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/domain/warehouse_location_service.dart';

/// Libellé du panier "marque non reconnue" — un produit dont le nom ne
/// commence par aucune marque déjà enregistrée (Module 5 v2, Rubrique 2),
/// ou une demande sans nom de produit enregistré (créée avant
/// l'introduction de cet instantané, voir `CourierRequest.produitNom`).
/// Jamais fusionné silencieusement avec une vraie marque : l'apparition
/// de ce panier avec un total élevé signale à l'administrateur qu'il
/// gagnerait à enregistrer cette marque dans "Emplacements".
const String marqueNonIdentifiee = 'Marque non identifiée';

/// Statistiques des demandes coursier ("produit introuvable") pour UNE
/// marque — Module 5 v2, Rubrique 4bis (16/09/2026) : objectif, repérer
/// les marques qui manquent le plus souvent en rayon, pour soit augmenter
/// leur volume de stockage (cas [nonTrouves] élevé : le produit est
/// réellement épuisé), soit repriorité leur emplacement dans l'entrepôt
/// (cas [trouves] élevé : le coursier le retrouve à chaque fois, c'est
/// donc que le préparateur ne le voit pas assez vite à sa place actuelle).
class BrandRequestStat {
  const BrandRequestStat({
    required this.marque,
    required this.total,
    required this.trouves,
    required this.nonTrouves,
  });

  final String marque;

  /// Nombre total de demandes coursier pour cette marque, quel que soit
  /// leur état actuel (encore en cours, ou déjà closes).
  final int total;

  /// Closes avec le produit finalement retrouvé.
  final int trouves;

  /// Closes avec le produit non retrouvé — le signal le plus direct d'un
  /// vrai manque de stock.
  final int nonTrouves;

  /// Encore ouvertes (le coursier n'a pas encore répondu) — ni [trouves]
  /// ni [nonTrouves], jamais compté deux fois.
  int get enCours => total - trouves - nonTrouves;
}

/// Regroupe [demandes] par marque (même règle de correspondance que
/// [WarehouseLocationService.matchMarque] — jamais une règle différente
/// pour les statistiques que pour l'affichage courant), triées de la plus
/// fréquente à la moins fréquente.
///
/// Fonction pure, testable sans dépôt ni `Future` : [AdministrationService]
/// se contente de charger les deux listes puis d'appeler ceci.
List<BrandRequestStat> computeBrandRequestStats(
  List<CourierRequest> demandes,
  List<BrandWarehouseLocation> marques,
) {
  final parMarque = <String, List<CourierRequest>>{};
  for (final demande in demandes) {
    final nomProduit = demande.produitNom;
    final correspondance =
        nomProduit == null ? null : WarehouseLocationService.matchMarque(nomProduit, marques);
    final cle = correspondance?.marque ?? marqueNonIdentifiee;
    parMarque.putIfAbsent(cle, () => []).add(demande);
  }

  final resultats = [
    for (final entry in parMarque.entries)
      BrandRequestStat(
        marque: entry.key,
        total: entry.value.length,
        trouves: entry.value
            .where((d) => d.resultat == CourierRequestResult.retrouve)
            .length,
        nonTrouves: entry.value
            .where((d) => d.resultat == CourierRequestResult.nonRetrouve)
            .length,
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));

  return resultats;
}
