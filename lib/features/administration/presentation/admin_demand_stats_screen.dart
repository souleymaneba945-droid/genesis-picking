import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/status/stat_card.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/administration/domain/demand_stats.dart';
import 'package:genesis_picking/features/administration/domain/stats_period.dart';
import 'package:genesis_picking/features/administration/presentation/widgets/demand_stat_widgets.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';

enum _StatutFiltre { tous, trouve, nonTrouve }

/// "Statistiques de demande logistique" (Module 5 v2, Rubrique 4ter,
/// 16/09/2026) — analyse l'historique des demandes coursier ("produit
/// introuvable") pour identifier les produits/marques les plus recherchés
/// et orienter l'organisation physique de l'entrepôt.
///
/// RÈGLE ABSOLUE (cahier des charges utilisateur) : cet écran ne connaît
/// et ne prétend JAMAIS connaître le stock physique — uniquement la
/// fréquence des demandes déjà enregistrées. Voir `demand_stats.dart`.
///
/// Remplace l'ancien écran "Statistiques par marque" (même point d'accès
/// depuis "Suivi") — ce dernier, ajouté puis aussitôt élargi dans la même
/// session, n'était pas encore un point de passage établi de l'app.
class AdminDemandStatsScreen extends ConsumerStatefulWidget {
  const AdminDemandStatsScreen({super.key});

  @override
  ConsumerState<AdminDemandStatsScreen> createState() => _AdminDemandStatsScreenState();
}

class _AdminDemandStatsScreenState extends ConsumerState<AdminDemandStatsScreen> {
  late Future<({List<CourierRequest> demandes, List<BrandWarehouseLocation> marques})> _donneesFuture;

  StatsPeriodGranularity _granularite = StatsPeriodGranularity.jour;
  DateTime _ancre = DateTime.now();
  DateTimeRange? _plagePersonnalisee;

  String? _filtreMarque;
  String? _filtreEmplacement;
  _StatutFiltre _filtreStatut = _StatutFiltre.tous;
  final _rechercheController = TextEditingController();
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _donneesFuture =
        ref.read(administrationServiceProvider).chargerDonneesStatistiquesMarque();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) get _bornesPeriode {
    final plage = _plagePersonnalisee;
    if (plage != null) {
      return (
        DateTime(plage.start.year, plage.start.month, plage.start.day),
        DateTime(plage.end.year, plage.end.month, plage.end.day).add(const Duration(days: 1)),
      );
    }
    return periodBounds(_ancre, _granularite);
  }

  (DateTime, DateTime) get _bornesPeriodePrecedente {
    if (_plagePersonnalisee != null) {
      final (debut, fin) = _bornesPeriode;
      final duree = fin.difference(debut);
      return (debut.subtract(duree), debut);
    }
    final ancrePrecedente = shiftPeriod(_ancre, _granularite, -1);
    return periodBounds(ancrePrecedente, _granularite);
  }

  Future<void> _choisirPeriodePersonnalisee() async {
    final maintenant = DateTime.now();
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(maintenant.year - 2),
      lastDate: maintenant,
      initialDateRange: _plagePersonnalisee ??
          DateTimeRange(start: maintenant.subtract(const Duration(days: 7)), end: maintenant),
    );
    if (plage == null) return;
    setState(() => _plagePersonnalisee = plage);
  }

  void _choisirGranularite(StatsPeriodGranularity g) {
    setState(() {
      _granularite = g;
      _plagePersonnalisee = null;
    });
  }

  void _naviguer(int direction) {
    setState(() => _ancre = shiftPeriod(_ancre, _granularite, direction));
  }

  void _reinitialiserFiltres() {
    setState(() {
      _filtreMarque = null;
      _filtreEmplacement = null;
      _filtreStatut = _StatutFiltre.tous;
      _rechercheController.clear();
      _recherche = '';
    });
  }

  List<CourierRequest> _appliquerFiltresBruts(
    List<CourierRequest> demandes,
    DateTime debut,
    DateTime finExclue,
  ) {
    var resultat = filterByPeriod(demandes, debut, finExclue);
    if (_filtreEmplacement != null) {
      resultat = resultat.where((d) => d.emplacement == _filtreEmplacement).toList();
    }
    switch (_filtreStatut) {
      case _StatutFiltre.trouve:
        resultat = resultat.where((d) => d.resultat == CourierRequestResult.retrouve).toList();
      case _StatutFiltre.nonTrouve:
        resultat = resultat.where((d) => d.resultat == CourierRequestResult.nonRetrouve).toList();
      case _StatutFiltre.tous:
        break;
    }
    return resultat;
  }

  List<ProductDemandStat> _appliquerFiltresProduits(List<ProductDemandStat> stats) {
    var resultat = stats;
    if (_filtreMarque != null) {
      resultat = resultat.where((s) => s.marque == _filtreMarque).toList();
    }
    if (_recherche.isNotEmpty) {
      final q = _recherche.toLowerCase();
      resultat = resultat
          .where(
            (s) =>
                s.produitNom.toLowerCase().contains(q) ||
                (s.sku?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return resultat;
  }

  Future<void> _exporterCsv(List<ProductDemandStat> stats, String labelPeriode) async {
    final lignes = <List<String>>[
      [
        'Période',
        'Produit',
        'SKU',
        'Marque',
        'Nombre de recherches',
        'Part de demande (%)',
        'Tendance',
        'Priorité picking',
        'Recherches non trouvées',
      ],
      for (final s in stats)
        [
          labelPeriode,
          s.produitNom,
          s.sku ?? '',
          s.marque,
          '${s.total}',
          s.partDemandePourcent.toStringAsFixed(1),
          _libelleTendanceCourt(s.trend),
          _libellePriorite(s.prioritePicking),
          '${s.nonTrouves}',
        ],
    ];
    final csv = const ListToCsvConverter().convert(lignes);
    final bytes = Uint8List.fromList(utf8.encode('﻿$csv')); // BOM → Excel FR lit les accents

    final chemin = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter les statistiques',
      fileName: 'statistiques_demande.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );
    if (chemin == null || !mounted) return;

    // Défensif : certaines implémentations desktop de file_picker renvoient
    // le chemin sans avoir réellement écrit `bytes` — on l'écrit nous-même
    // pour ne jamais dépendre de ce détail d'implémentation.
    try {
      final fichier = File(chemin);
      if (!await fichier.exists() || await fichier.length() == 0) {
        await fichier.writeAsBytes(bytes);
      }
    } catch (_) {
      // Best-effort : si l'écriture directe échoue (permissions, chemin
      // déjà géré par le plugin), on ne bloque pas l'utilisateur pour ça.
    }

    if (!mounted) return;
    AppSnackbar.showSuccess(context, 'Export enregistré : $chemin');
  }

  @override
  Widget build(BuildContext context) {
    // Pas d'AppBar propre (Modernisation visuelle) : depuis le 16/09/2026,
    // cet écran est un onglet à part entière de `AdminShell`, sous la barre
    // supérieure déjà fournie par `RoleShell` — même principe que
    // `SettingsScreen`/`WarehouseLocationManagementScreen`. Le titre "
    // STATISTIQUES DE DEMANDE LOGISTIQUE" déjà affiché en tête de liste
    // suffit.
    return FutureBuilder<({List<CourierRequest> demandes, List<BrandWarehouseLocation> marques})>(
        future: _donneesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Impossible de charger les statistiques.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final toutesLesDemandes = snapshot.data!.demandes;
          final marquesConnues = snapshot.data!.marques;

          final (debut, finExclue) = _bornesPeriode;
          final (debutPrecedent, finPrecedente) = _bornesPeriodePrecedente;

          final demandesPeriode = _appliquerFiltresBruts(toutesLesDemandes, debut, finExclue);
          final demandesPeriodePrecedente =
              _appliquerFiltresBruts(toutesLesDemandes, debutPrecedent, finPrecedente);

          final statsCompletes = computeProductDemandStats(
            demandesPeriode: demandesPeriode,
            demandesPeriodePrecedente: demandesPeriodePrecedente,
            marques: marquesConnues,
          );
          final statsPrecedentes = computeProductDemandStats(
            demandesPeriode: demandesPeriodePrecedente,
            demandesPeriodePrecedente: const [],
            marques: marquesConnues,
          );
          final stats = _appliquerFiltresProduits(statsCompletes);

          final marquesDisponibles = statsCompletes.map((s) => s.marque).toSet().toList()..sort();
          final emplacementsDisponibles = demandesPeriode.map((d) => d.emplacement).toSet().toList()
            ..sort();

          final totalRecherches = stats.fold<int>(0, (s, p) => s + p.total);
          final nonTrouvees = stats.fold<int>(0, (s, p) => s + p.nonTrouves);
          final forteDemande = stats
              .where(
                (p) =>
                    p.classification == DemandClassification.tresForte ||
                    p.classification == DemandClassification.forte,
              )
              .length;
          final enHausse =
              stats.where((p) => p.trend.direction == DemandTrendDirection.hausse).length;

          final brandStats = computeBrandDemandStats(stats, statsPrecedentes);
          final locationStats = computeLocationDemandStats(stats, demandesPeriode);
          final observations = genererObservationsLogistiques(stats, totalRecherches);

          final estPeriodeActuelle = _plagePersonnalisee == null &&
              !DateTime.now().isBefore(debut) &&
              DateTime.now().isBefore(finExclue);
          final labelPeriode = _plagePersonnalisee != null
              ? _libellePersonnalise(_plagePersonnalisee!)
              : periodLabel(debut, finExclue, _granularite);

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            children: [
              const Text(
                'STATISTIQUES DE DEMANDE LOGISTIQUE',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              const Text(
                'Analyse des recherches enregistrées afin d\'identifier les '
                'produits et marques les plus demandés et d\'optimiser leur '
                'organisation logistique. Basé uniquement sur les demandes '
                'coursier déjà enregistrées — jamais sur un stock réel.',
                style: AppTypography.secondaryLabel,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              PeriodGranulariteSelector(
                selectionnee: _plagePersonnalisee != null ? null : _granularite,
                onChanged: _choisirGranularite,
                onPersonnalise: _choisirPeriodePersonnalisee,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              PeriodeNavigator(
                label: labelPeriode,
                onPrecedent: _plagePersonnalisee != null ? null : () => _naviguer(-1),
                onSuivant: _plagePersonnalisee != null || estPeriodeActuelle ? null : () => _naviguer(1),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              DemandFiltersBar(
                marques: marquesDisponibles,
                emplacements: emplacementsDisponibles,
                marqueSelectionnee: _filtreMarque,
                emplacementSelectionne: _filtreEmplacement,
                statutSelectionne: _filtreStatut.name,
                rechercheController: _rechercheController,
                onMarqueChanged: (v) => setState(() => _filtreMarque = v),
                onEmplacementChanged: (v) => setState(() => _filtreEmplacement = v),
                onStatutChanged: (v) => setState(
                  () => _filtreStatut = _StatutFiltre.values.firstWhere((s) => s.name == v),
                ),
                onRechercheChanged: (v) => setState(() => _recherche = v),
                onReset: _reinitialiserFiltres,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: AppDimensions.spacingSm,
                mainAxisSpacing: AppDimensions.spacingSm,
                childAspectRatio: 1.7,
                children: [
                  StatCard(value: '$totalRecherches', label: 'Recherches totales', icon: Icons.inventory_2_outlined),
                  StatCard(value: '${stats.length}', label: 'Produits recherchés', icon: Icons.label_outline),
                  StatCard(
                    value: '${stats.map((s) => s.marque).toSet().length}',
                    label: 'Marques recherchées',
                    icon: Icons.storefront_outlined,
                  ),
                  StatCard(value: '$forteDemande', label: 'Forte demande', icon: Icons.local_fire_department_outlined, color: AppColors.error),
                  StatCard(value: '$enHausse', label: 'Demande en hausse', icon: Icons.trending_up, color: AppColors.success),
                  StatCard(value: '$nonTrouvees', label: 'Recherches non trouvées', icon: Icons.error_outline, color: AppColors.warningText),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              if (stats.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXl),
                  child: Center(
                    child: Text(
                      'Aucune demande coursier sur cette période/ces filtres.',
                      textAlign: TextAlign.center,
                      style: AppTypography.secondaryLabel,
                    ),
                  ),
                )
              else ...[
                SectionHeader(
                  icon: Icons.bar_chart_outlined,
                  title: 'Top produits les plus recherchés',
                  trailing: OutlinedButton.icon(
                    onPressed: () => _exporterCsv(stats, labelPeriode),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Exporter'),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                TopProductsChart(stats: stats.take(12).toList()),
                const SizedBox(height: AppDimensions.spacingLg),
                const SectionHeader(icon: Icons.table_chart_outlined, title: 'Produits les plus demandés'),
                const SizedBox(height: AppDimensions.spacingSm),
                ProductDemandTable(stats: stats),
                if (observations.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingLg),
                  const SectionHeader(icon: Icons.insights_outlined, title: 'Observations logistiques'),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ObservationsCard(observations: observations),
                ],
                const SizedBox(height: AppDimensions.spacingLg),
                const SectionHeader(icon: Icons.storefront_outlined, title: 'Demande par marque'),
                const SizedBox(height: AppDimensions.spacingSm),
                for (final b in brandStats) ...[
                  BrandDemandCard(
                    stat: b,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BrandDemandDetailScreen(
                          marque: b.marque,
                          produits: statsCompletes.where((s) => s.marque == b.marque).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],
                if (locationStats.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingLg),
                  const SectionHeader(icon: Icons.location_on_outlined, title: 'Analyse des emplacements'),
                  const SizedBox(height: AppDimensions.spacingSm),
                  for (final l in locationStats) ...[
                    LocationDemandCard(stat: l),
                    const SizedBox(height: AppDimensions.spacingSm),
                  ],
                ],
              ],
            ],
          );
        },
      );
  }
}

String _libellePersonnalise(DateTimeRange plage) {
  String deux(int n) => n.toString().padLeft(2, '0');
  final d = plage.start;
  final f = plage.end;
  return '${deux(d.day)}/${deux(d.month)}/${d.year} au ${deux(f.day)}/${deux(f.month)}/${f.year}';
}

String _libelleTendanceCourt(DemandTrend t) => switch (t.direction) {
      DemandTrendDirection.hausse => 'Hausse',
      DemandTrendDirection.baisse => 'Baisse',
      DemandTrendDirection.stable => 'Stable',
      DemandTrendDirection.insuffisant => 'Données insuffisantes',
    };

String _libellePriorite(PickingPriority p) => switch (p) {
      PickingPriority.prioritePicking => 'Priorité picking',
      PickingPriority.aRapprocher => 'À rapprocher',
      PickingPriority.aSurveiller => 'À surveiller',
      PickingPriority.organisationStandard => 'Organisation standard',
    };
