import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/features/administration/domain/demand_stats.dart';
import 'package:genesis_picking/features/administration/domain/stats_period.dart';

/// Widgets partagés de l'écran "Statistiques de demande" (Module 5 v2,
/// Rubrique 4ter, 16/09/2026) — extraits du fichier écran principal pour
/// rester lisibles, mêmes règles que `demand_stats.dart` (jamais un mot
/// évoquant une rupture de stock réelle : voir [_libelleTendance] et
/// [_libellePriorite]).

// --- Sélecteur de période -------------------------------------------

class PeriodGranulariteSelector extends StatelessWidget {
  const PeriodGranulariteSelector({
    required this.selectionnee,
    required this.onChanged,
    required this.onPersonnalise,
    super.key,
  });

  /// `null` quand une période personnalisée est active — aucun des 3
  /// segments n'est alors mis en évidence.
  final StatsPeriodGranularity? selectionnee;
  final ValueChanged<StatsPeriodGranularity> onChanged;
  final VoidCallback onPersonnalise;

  String _libelle(StatsPeriodGranularity g) => switch (g) {
        StatsPeriodGranularity.jour => 'Jour',
        StatsPeriodGranularity.semaine => 'Semaine',
        StatsPeriodGranularity.mois => 'Mois',
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final g in StatsPeriodGranularity.values) ...[
            _Segment(label: _libelle(g), selected: g == selectionnee, onTap: () => onChanged(g)),
            const SizedBox(width: AppDimensions.spacingXs),
          ],
          _Segment(
            label: 'Période personnalisée',
            selected: selectionnee == null,
            onTap: onPersonnalise,
            icon: Icons.date_range_outlined,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeriodeNavigator extends StatelessWidget {
  const PeriodeNavigator({required this.label, required this.onPrecedent, required this.onSuivant, super.key});

  final String label;
  final VoidCallback? onPrecedent;
  final VoidCallback? onSuivant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrecedent,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Période précédente',
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: onSuivant,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Période suivante',
        ),
      ],
    );
  }
}

// --- Filtres -----------------------------------------------------------

class DemandFiltersBar extends StatelessWidget {
  const DemandFiltersBar({
    required this.marques,
    required this.emplacements,
    required this.marqueSelectionnee,
    required this.emplacementSelectionne,
    required this.statutSelectionne,
    required this.rechercheController,
    required this.onMarqueChanged,
    required this.onEmplacementChanged,
    required this.onStatutChanged,
    required this.onRechercheChanged,
    required this.onReset,
    super.key,
  });

  final List<String> marques;
  final List<String> emplacements;
  final String? marqueSelectionnee;
  final String? emplacementSelectionne;
  final String statutSelectionne;
  final TextEditingController rechercheController;
  final ValueChanged<String?> onMarqueChanged;
  final ValueChanged<String?> onEmplacementChanged;
  final ValueChanged<String?> onStatutChanged;
  final ValueChanged<String> onRechercheChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: rechercheController,
              onChanged: onRechercheChanged,
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit ou une référence',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: marqueSelectionnee,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Marque'),
                    items: [
                      const DropdownMenuItem(child: Text('Toutes')),
                      for (final m in marques) DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: onMarqueChanged,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: emplacementSelectionne,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Emplacement'),
                    items: [
                      const DropdownMenuItem(child: Text('Tous')),
                      for (final e in emplacements) DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: onEmplacementChanged,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: statutSelectionne,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: const [
                      DropdownMenuItem(value: 'tous', child: Text('Tous')),
                      DropdownMenuItem(value: 'trouve', child: Text('Trouvé')),
                      DropdownMenuItem(value: 'nonTrouve', child: Text('Non trouvé')),
                    ],
                    onChanged: onStatutChanged,
                  ),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text('Réinitialiser'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Section header ------------------------------------------------------

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.icon, required this.title, this.trailing, super.key});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppDimensions.spacingXs),
        Expanded(child: Text(title, style: AppTypography.sectionTitle)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// --- Graphique "top produits" ------------------------------------------

class TopProductsChart extends StatelessWidget {
  const TopProductsChart({required this.stats, super.key});

  final List<ProductDemandStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final max = stats.first.total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in stats) ...[
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      s.produitNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : s.total / max,
                        minHeight: 14,
                        backgroundColor: AppColors.surfaceAlt,
                        color: _couleurClassification(s.classification),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  SizedBox(
                    width: 28,
                    child: Text('${s.total}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Tableau produits ----------------------------------------------------

class ProductDemandTable extends StatelessWidget {
  const ProductDemandTable({required this.stats, super.key});

  final List<ProductDemandStat> stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
          columns: const [
            DataColumn(label: Text('Rang')),
            DataColumn(label: Text('Produit')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Marque')),
            DataColumn(label: Text('Recherches'), numeric: true),
            DataColumn(label: Text('Part')),
            DataColumn(label: Text('Tendance')),
            DataColumn(label: Text('Statut logistique')),
          ],
          rows: [
            for (var i = 0; i < stats.length; i++) _ligne(i + 1, stats[i]),
          ],
        ),
      ),
    );
  }

  DataRow _ligne(int rang, ProductDemandStat s) {
    return DataRow(
      cells: [
        DataCell(Text('$rang')),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(s.produitNom, overflow: TextOverflow.ellipsis),
        )),
        DataCell(Text(s.sku ?? '—')),
        DataCell(Text(s.marque)),
        DataCell(Text('${s.total}')),
        DataCell(Text('${s.partDemandePourcent.toStringAsFixed(1)} %')),
        DataCell(_TendanceChip(trend: s.trend)),
        DataCell(_ClassificationBadge(classification: s.classification)),
      ],
    );
  }
}

class _TendanceChip extends StatelessWidget {
  const _TendanceChip({required this.trend});

  final DemandTrend trend;

  @override
  Widget build(BuildContext context) {
    final (icon, couleur, texte) = switch (trend.direction) {
      DemandTrendDirection.hausse => (
          Icons.trending_up,
          AppColors.success,
          '+${trend.variationPourcent!.toStringAsFixed(0)} %',
        ),
      DemandTrendDirection.baisse => (
          Icons.trending_down,
          AppColors.error,
          '${trend.variationPourcent!.toStringAsFixed(0)} %',
        ),
      DemandTrendDirection.stable => (Icons.trending_flat, AppColors.textSecondary, 'Stable'),
      DemandTrendDirection.insuffisant => (Icons.remove, AppColors.textSecondary, 'Données insuffisantes'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: couleur),
        const SizedBox(width: 3),
        Text(texte, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: couleur)),
      ],
    );
  }
}

class _ClassificationBadge extends StatelessWidget {
  const _ClassificationBadge({required this.classification});

  final DemandClassification classification;

  @override
  Widget build(BuildContext context) {
    final (emoji, label, couleur) = switch (classification) {
      DemandClassification.tresForte => ('🔴', 'Très forte demande', AppColors.error),
      DemandClassification.forte => ('🟠', 'Forte demande', AppColors.warningText),
      DemandClassification.moderee => ('🟡', 'Demande modérée', AppColors.warningText),
      DemandClassification.faible => ('🟢', 'Faible demande', AppColors.success),
    };
    return Text('$emoji $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: couleur));
  }
}

Color _couleurClassification(DemandClassification c) => switch (c) {
      DemandClassification.tresForte => AppColors.error,
      DemandClassification.forte => AppColors.warningText,
      DemandClassification.moderee => AppColors.warning,
      DemandClassification.faible => AppColors.primary,
    };

// --- Observations --------------------------------------------------------

class ObservationsCard extends StatelessWidget {
  const ObservationsCard({required this.observations, super.key});

  final List<String> observations;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primarySoft,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final o in observations) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 6, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(child: Text(o, style: AppTypography.body)),
                ],
              ),
              if (o != observations.last) const SizedBox(height: AppDimensions.spacingSm),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Marque ----------------------------------------------------------------

class BrandDemandCard extends StatelessWidget {
  const BrandDemandCard({required this.stat, required this.onTap, super.key});

  final BrandDemandStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.marque, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${stat.total} recherches · ${stat.produitsDistincts} produits · '
                      '${stat.partDemandePourcent.toStringAsFixed(1)} % · '
                      '${stat.produitsForteDemande} en forte demande',
                      style: AppTypography.secondaryLabel,
                    ),
                  ],
                ),
              ),
              _TendanceChip(trend: stat.trend),
              const SizedBox(width: AppDimensions.spacingXs),
              const Icon(Icons.chevron_right, color: AppColors.neutral, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Détail d'une marque (cahier des charges §10) — tous ses produits, avec
/// les mêmes colonnes que le tableau principal.
class BrandDemandDetailScreen extends StatelessWidget {
  const BrandDemandDetailScreen({required this.marque, required this.produits, super.key});

  final String marque;
  final List<ProductDemandStat> produits;

  @override
  Widget build(BuildContext context) {
    final total = produits.fold<int>(0, (s, p) => s + p.total);

    return Scaffold(
      appBar: AppBar(title: Text('Marque : $marque')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCardMini(value: '$total', label: 'Recherches totales'),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: StatCardMini(value: '${produits.length}', label: 'Références recherchées'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          const SectionHeader(icon: Icons.table_chart_outlined, title: 'Produits de la marque'),
          const SizedBox(height: AppDimensions.spacingSm),
          ProductDemandTable(stats: produits),
        ],
      ),
    );
  }
}

class StatCardMini extends StatelessWidget {
  const StatCardMini({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.statValue),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(label, style: AppTypography.secondaryLabel),
          ],
        ),
      ),
    );
  }
}

// --- Emplacement -----------------------------------------------------------

class LocationDemandCard extends StatelessWidget {
  const LocationDemandCard({required this.stat, super.key});

  final LocationDemandStat stat;

  bool get _aVerifier => stat.tauxNonTrouvePourcent >= 30 && stat.total >= 3;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(stat.emplacement, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
                ),
                Text('${stat.total}', style: AppTypography.statValue.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${stat.produitsDistincts} produits · ${stat.marquesDistinctes} marques · '
              '${stat.nonTrouves} non trouvé${stat.nonTrouves > 1 ? 's' : ''} '
              '(${stat.tauxNonTrouvePourcent.toStringAsFixed(0)} %)',
              style: AppTypography.secondaryLabel,
            ),
            if (_aVerifier) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.warningText),
                  SizedBox(width: 4),
                  Text(
                    'Emplacement à vérifier',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningText),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
