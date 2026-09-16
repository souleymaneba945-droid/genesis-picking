import 'package:genesis_picking/features/administration/domain/brand_request_stats.dart'
    show marqueNonIdentifiee;
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/domain/warehouse_location_service.dart';

/// Statistiques de demande logistique (Module 5 v2, Rubrique 4ter,
/// 16/09/2026) — analyse UNIQUEMENT l'historique des demandes coursier
/// ("produit introuvable") déjà enregistré dans l'app.
///
/// RÈGLE ABSOLUE (cahier des charges utilisateur, §18) : ce fichier ne
/// connaît et ne doit JAMAIS prétendre connaître le stock physique, la
/// quantité restante, vendue ou réapprovisionnée — la seule source de
/// vérité est la fréquence des demandes coursier déjà enregistrées.
/// Un total élevé signifie "recherché souvent", jamais "en rupture".

/// Libellé du panier "produit non identifié" — une demande sans nom de
/// produit connu (donnée créée avant l'instantané produit, voir
/// `CourierRequest.produitNom`). Jamais fusionné avec un vrai produit.
const String produitNonIdentifie = 'Produit non identifié';

/// Seuils de classification — RELATIFS au produit/à la marque le plus
/// demandé de la période (cahier des charges §7 : "classification relative
/// aux autres produits de la période"), jamais un total absolu figé.
/// Seule source de vérité pour ces seuils : les modifier ICI, nulle part
/// ailleurs.
class DemandThresholds {
  DemandThresholds._();

  /// Un produit/une marque à ≥ 75 % du total du plus demandé de la
  /// période → très forte demande.
  static const double tresForteRatio = 0.75;
  static const double forteRatio = 0.50;
  static const double othModereeRatio = 0.25;
  // En dessous de [othModereeRatio] → faible demande.

  /// Variation (période actuelle vs période précédente équivalente) à
  /// partir de laquelle on parle de hausse/baisse plutôt que de stabilité.
  static const double tendanceHausseSeuil = 0.15; // +15 %
  static const double tendanceBaisseSeuil = -0.15; // -15 %
}

enum DemandClassification { tresForte, forte, moderee, faible }

/// "PRIORITÉ PICKING" = "produit fréquemment recherché — à considérer
/// pour un emplacement facilement accessible". Ne signifie JAMAIS
/// "produit en rupture" (cahier des charges §8).
enum PickingPriority { prioritePicking, aRapprocher, aSurveiller, organisationStandard }

PickingPriority pickingPriorityFor(DemandClassification c) => switch (c) {
      DemandClassification.tresForte => PickingPriority.prioritePicking,
      DemandClassification.forte => PickingPriority.aRapprocher,
      DemandClassification.moderee => PickingPriority.aSurveiller,
      DemandClassification.faible => PickingPriority.organisationStandard,
    };

DemandClassification classifyDemand(int total, int maxTotalPeriode) {
  if (maxTotalPeriode <= 0) return DemandClassification.faible;
  final ratio = total / maxTotalPeriode;
  if (ratio >= DemandThresholds.tresForteRatio) return DemandClassification.tresForte;
  if (ratio >= DemandThresholds.forteRatio) return DemandClassification.forte;
  if (ratio >= DemandThresholds.othModereeRatio) return DemandClassification.moderee;
  return DemandClassification.faible;
}

enum DemandTrendDirection { hausse, baisse, stable, insuffisant }

class DemandTrend {
  const DemandTrend({required this.direction, this.variationPourcent});

  final DemandTrendDirection direction;

  /// `null` uniquement quand [direction] est
  /// [DemandTrendDirection.insuffisant] (pas de période précédente à
  /// comparer — cahier des charges §6 : "ne pas utiliser une tendance si
  /// les données disponibles sont insuffisantes").
  final double? variationPourcent;
}

/// Compare [actuel] à [precedent] (même granularité, période juste
/// avant) — jamais une régression sur plusieurs périodes, un simple
/// rapport à deux points suffit pour rester explicable et testable.
DemandTrend computeTrend(int actuel, int precedent) {
  if (precedent == 0) {
    return const DemandTrend(direction: DemandTrendDirection.insuffisant);
  }
  final variation = (actuel - precedent) / precedent;
  if (variation >= DemandThresholds.tendanceHausseSeuil) {
    return DemandTrend(direction: DemandTrendDirection.hausse, variationPourcent: variation * 100);
  }
  if (variation <= DemandThresholds.tendanceBaisseSeuil) {
    return DemandTrend(direction: DemandTrendDirection.baisse, variationPourcent: variation * 100);
  }
  return DemandTrend(direction: DemandTrendDirection.stable, variationPourcent: variation * 100);
}

/// Clé de regroupement d'une demande par "produit" pour les statistiques
/// — la référence exacte (`produitDescription`, même champ que le
/// regroupement coursier de la Rubrique 1) quand elle existe ; à défaut
/// le nom du produit (contrairement à la Rubrique 1, qui ne fusionne
/// JAMAIS deux demandes sans référence entre elles pour rester sûre côté
/// action coursier — ici, un simple comptage rétrospectif, fusionner par
/// nom reste plus utile qu'une multitude de lignes à une seule demande).
String demandProductKey(CourierRequest r) {
  final ref = r.produitDescription;
  if (ref != null && ref.isNotEmpty) return ref;
  final nom = r.produitNom;
  if (nom != null && nom.isNotEmpty) return nom;
  return produitNonIdentifie;
}

class ProductDemandStat {
  const ProductDemandStat({
    required this.cle,
    required this.produitNom,
    required this.sku,
    required this.marque,
    required this.total,
    required this.trouves,
    required this.nonTrouves,
    required this.partDemandePourcent,
    required this.trend,
    required this.classification,
  });

  final String cle;
  final String produitNom;

  /// `null` quand aucune référence n'a jamais accompagné ce produit sur
  /// la période — jamais une valeur inventée.
  final String? sku;
  final String marque;
  final int total;
  final int trouves;
  final int nonTrouves;
  final double partDemandePourcent;
  final DemandTrend trend;
  final DemandClassification classification;

  PickingPriority get prioritePicking => pickingPriorityFor(classification);
  int get enCours => total - trouves - nonTrouves;
}

/// Calcule les statistiques par produit de [demandesPeriode], la tendance
/// étant déterminée par comparaison avec [demandesPeriodePrecedente]
/// (même clé de regroupement, [demandProductKey]).
List<ProductDemandStat> computeProductDemandStats({
  required List<CourierRequest> demandesPeriode,
  required List<CourierRequest> demandesPeriodePrecedente,
  required List<BrandWarehouseLocation> marques,
}) {
  if (demandesPeriode.isEmpty) return const [];

  final parCle = <String, List<CourierRequest>>{};
  for (final d in demandesPeriode) {
    parCle.putIfAbsent(demandProductKey(d), () => []).add(d);
  }

  final totauxPrecedents = <String, int>{};
  for (final d in demandesPeriodePrecedente) {
    final cle = demandProductKey(d);
    totauxPrecedents[cle] = (totauxPrecedents[cle] ?? 0) + 1;
  }

  final totalPeriode = demandesPeriode.length;
  final maxTotal = parCle.values.map((l) => l.length).reduce((a, b) => a > b ? a : b);

  final resultats = [
    for (final entry in parCle.entries)
      _buildProductStat(
        cle: entry.key,
        demandes: entry.value,
        totalPeriode: totalPeriode,
        maxTotal: maxTotal,
        totalPrecedent: totauxPrecedents[entry.key] ?? 0,
        marques: marques,
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));

  return resultats;
}

ProductDemandStat _buildProductStat({
  required String cle,
  required List<CourierRequest> demandes,
  required int totalPeriode,
  required int maxTotal,
  required int totalPrecedent,
  required List<BrandWarehouseLocation> marques,
}) {
  final premiere = demandes.first;
  final nom = premiere.produitNom ?? cle;
  final correspondance =
      premiere.produitNom == null ? null : WarehouseLocationService.matchMarque(premiere.produitNom!, marques);

  return ProductDemandStat(
    cle: cle,
    produitNom: nom,
    sku: premiere.produitDescription,
    marque: correspondance?.marque ?? marqueNonIdentifiee,
    total: demandes.length,
    trouves: demandes.where((d) => d.resultat == CourierRequestResult.retrouve).length,
    nonTrouves: demandes.where((d) => d.resultat == CourierRequestResult.nonRetrouve).length,
    partDemandePourcent: totalPeriode == 0 ? 0 : demandes.length / totalPeriode * 100,
    trend: computeTrend(demandes.length, totalPrecedent),
    classification: classifyDemand(demandes.length, maxTotal),
  );
}

/// Statistiques agrégées par marque (cahier des charges §9/§10) —
/// calculées à partir des [ProductDemandStat] déjà produits, jamais
/// recalculées séparément depuis les demandes brutes (une seule règle de
/// correspondance marque, un seul endroit qui l'applique).
class BrandDemandStat {
  const BrandDemandStat({
    required this.marque,
    required this.total,
    required this.produitsDistincts,
    required this.partDemandePourcent,
    required this.produitsForteDemande,
    required this.trend,
  });

  final String marque;
  final int total;
  final int produitsDistincts;
  final double partDemandePourcent;

  /// Nombre de produits de cette marque classés forte/très forte demande.
  final int produitsForteDemande;
  final DemandTrend trend;
}

List<BrandDemandStat> computeBrandDemandStats(
  List<ProductDemandStat> produitsPeriode,
  List<ProductDemandStat> produitsPeriodePrecedente,
) {
  if (produitsPeriode.isEmpty) return const [];

  final parMarque = <String, List<ProductDemandStat>>{};
  for (final p in produitsPeriode) {
    parMarque.putIfAbsent(p.marque, () => []).add(p);
  }

  final totauxPrecedents = <String, int>{};
  for (final p in produitsPeriodePrecedente) {
    totauxPrecedents[p.marque] = (totauxPrecedents[p.marque] ?? 0) + p.total;
  }

  final totalPeriode = produitsPeriode.fold<int>(0, (s, p) => s + p.total);

  final resultats = [
    for (final entry in parMarque.entries)
      BrandDemandStat(
        marque: entry.key,
        total: entry.value.fold<int>(0, (s, p) => s + p.total),
        produitsDistincts: entry.value.length,
        partDemandePourcent: totalPeriode == 0
            ? 0
            : entry.value.fold<int>(0, (s, p) => s + p.total) / totalPeriode * 100,
        produitsForteDemande: entry.value
            .where(
              (p) =>
                  p.classification == DemandClassification.tresForte ||
                  p.classification == DemandClassification.forte,
            )
            .length,
        trend: computeTrend(
          entry.value.fold<int>(0, (s, p) => s + p.total),
          totauxPrecedents[entry.key] ?? 0,
        ),
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));

  return resultats;
}

/// Statistiques agrégées par emplacement de PICKING (cahier des charges
/// §11) — jamais l'emplacement entrepôt (Rubrique 2, par marque) : deux
/// notions distinctes, voir `MODULE_5_V2.md`.
class LocationDemandStat {
  const LocationDemandStat({
    required this.emplacement,
    required this.total,
    required this.produitsDistincts,
    required this.marquesDistinctes,
    required this.nonTrouves,
  });

  final String emplacement;
  final int total;
  final int produitsDistincts;
  final int marquesDistinctes;
  final int nonTrouves;

  double get tauxNonTrouvePourcent => total == 0 ? 0 : nonTrouves / total * 100;
}

List<LocationDemandStat> computeLocationDemandStats(
  List<ProductDemandStat> produitsPeriode,
  List<CourierRequest> demandesPeriode,
) {
  if (demandesPeriode.isEmpty) return const [];

  // Table de correspondance clé produit → marque, construite UNE fois —
  // jamais un `firstWhere` par demande, qui risquerait de retomber sur un
  // produit au hasard si la clé est introuvable (aucune marque inventée).
  final marqueParCle = {for (final p in produitsPeriode) p.cle: p.marque};

  final parEmplacement = <String, List<CourierRequest>>{};
  for (final d in demandesPeriode) {
    parEmplacement.putIfAbsent(d.emplacement, () => []).add(d);
  }

  final resultats = [
    for (final entry in parEmplacement.entries)
      LocationDemandStat(
        emplacement: entry.key,
        total: entry.value.length,
        produitsDistincts: entry.value.map(demandProductKey).toSet().length,
        marquesDistinctes: entry.value
            .map((d) => marqueParCle[demandProductKey(d)] ?? marqueNonIdentifiee)
            .toSet()
            .length,
        nonTrouves: entry.value.where((d) => d.resultat == CourierRequestResult.nonRetrouve).length,
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));

  return resultats;
}

/// Observations logistiques (cahier des charges §14) — phrases générées à
/// partir des données réelles, jamais une affirmation de rupture de
/// stock (voir règle en tête de fichier).
List<String> genererObservationsLogistiques(List<ProductDemandStat> stats, int totalPeriode) {
  if (stats.isEmpty || totalPeriode == 0) return const [];

  final observations = <String>[];

  final top3Total = stats.take(3).fold<int>(0, (s, p) => s + p.total);
  final top3Part = totalPeriode == 0 ? 0 : top3Total / totalPeriode * 100;
  if (stats.length >= 3 && top3Part >= 30) {
    observations.add(
      '${stats.length >= 3 ? 3 : stats.length} produits concentrent '
      '${top3Part.round()} % des recherches sur la période.',
    );
  }

  final enHausse = stats.where((p) => p.trend.direction == DemandTrendDirection.hausse).length;
  if (enHausse > 0) {
    observations.add(
      enHausse > 1
          ? '$enHausse références présentent une augmentation de leur fréquence de recherche.'
          : 'Une référence présente une augmentation de sa fréquence de recherche.',
    );
  }

  final forteDemande = stats
      .where(
        (p) =>
            p.classification == DemandClassification.tresForte ||
            p.classification == DemandClassification.forte,
      )
      .length;
  if (forteDemande > 0) {
    observations.add(
      forteDemande > 1
          ? '$forteDemande références sont fréquemment recherchées et pourraient être '
              'considérées pour une zone de picking facilement accessible.'
          : 'Une référence est fréquemment recherchée et pourrait être considérée pour '
              'une zone de picking facilement accessible.',
    );
  }

  return observations;
}
