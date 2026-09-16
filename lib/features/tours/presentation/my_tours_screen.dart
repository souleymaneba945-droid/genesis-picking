import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/chips/app_filter_chip.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/import/presentation/import_tour_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:genesis_picking/features/tours/presentation/tour_detail_screen.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_status_badge.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

/// Onglet "Ma tournée" du Préparateur — liste complète de ses tournées
/// (Refonte UI : contenu identique à l'ancien écran "Mes tournées", sans
/// AppBar propre — intégré comme onglet de [PreparateurShell]).
///
/// Source de donnée : [toursForPreparateurProvider] — un flux "en direct"
/// partagé avec [PreparateurHomeTab] (voir ce provider) : une nouvelle
/// tournée importée ailleurs, ou téléchargée depuis un autre appareil,
/// apparaît ici automatiquement, sans avoir besoin de rouvrir l'onglet.
///
/// Chaque carte ouvre l'écran "Détail d'une tournée" ; le bouton en bout de
/// carte reste une action rapide directe.
class MyToursScreen extends ConsumerStatefulWidget {
  const MyToursScreen({super.key});

  @override
  ConsumerState<MyToursScreen> createState() => _MyToursScreenState();
}

/// Filtre d'affichage de "Mes commandes" (Modernisation visuelle,
/// 12/09/2026, maquette v0.dev) — purement local à cet écran, ne change
/// jamais la donnée ni sa source : un simple sous-ensemble de
/// [toursForPreparateurProvider], jamais une nouvelle requête.
enum _FiltreTournee { toutes, aFaire, enCours, terminees }

class _MyToursScreenState extends ConsumerState<MyToursScreen> {
  final Set<String> _downloadingIds = {};
  _FiltreTournee _filtre = _FiltreTournee.toutes;

  String _libelleFiltre(_FiltreTournee f) => switch (f) {
        _FiltreTournee.toutes => 'Toutes',
        _FiltreTournee.aFaire => 'À faire',
        _FiltreTournee.enCours => 'En cours',
        _FiltreTournee.terminees => 'Terminées',
      };

  bool _correspond(Tour tour) {
    return switch (_filtre) {
      _FiltreTournee.toutes => true,
      _FiltreTournee.aFaire =>
        tour.statut == TourStatus.disponible || tour.statut == TourStatus.telechargee,
      _FiltreTournee.enCours => tour.statut == TourStatus.enCours,
      _FiltreTournee.terminees => tour.statut == TourStatus.terminee,
    };
  }

  /// À appeler après toute écriture LOCALE (téléchargement, suppression)
  /// qui ne serait pas automatiquement reflétée par le flux distant tant
  /// qu'aucun autre appareil n'a rien changé côté serveur — voir
  /// `toursForPreparateurProvider`, qui ne réémet sinon qu'au prochain
  /// événement Firestore.
  void _invalider() {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    ref.invalidate(toursForPreparateurProvider(session.userId));
  }

  Future<void> _download(Tour tour) async {
    setState(() => _downloadingIds.add(tour.id));
    final result = await ref.read(tourServiceProvider).downloadTour(tour.id);
    if (!mounted) return;
    setState(() => _downloadingIds.remove(tour.id));
    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Tournée téléchargée.');
        _invalider();
      },
      failure: (exception) => AppSnackbar.showError(
          context, ErrorHandler.userMessageFor(exception)),
    );
  }

  void _openDetail(Tour tour) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)))
        .then((_) => _invalider());
  }

  Future<void> _confirmerSuppression(Tour tour) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette tournée ?'),
        content: Text(
          tour.statut == TourStatus.enCours
              ? 'La tournée ${tour.numeroTournee} est en cours — sa '
                  'progression sera perdue. Cette action est définitive.'
              : 'La tournée ${tour.numeroTournee} sera définitivement '
                  'supprimée, sur cet appareil et sur les autres. Cette '
                  'action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;

    final result = await ref.read(tourServiceProvider).deleteTour(tour.id);
    if (!mounted) return;
    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Tournée supprimée.');
        _invalider();
      },
      failure: (exception) => AppSnackbar.showError(
          context, ErrorHandler.userMessageFor(exception)),
    );
  }

  void _openImport() {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                ImportTourScreen(fixedPreparateurId: session.userId),
          ),
        )
        .then((_) => _invalider());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final asyncTours = session == null
        ? const AsyncValue<List<Tour>>.data([])
        : ref.watch(toursForPreparateurProvider(session.userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        // Tag explicite : les 4 onglets du shell Préparateur sont montés
        // simultanément (IndexedStack) — un FAB sans tag propre entre en
        // conflit avec celui d'un autre onglet (voir la même note dans
        // admin_dashboard_screen.dart, où ce bug a été découvert).
        heroTag: 'preparateur-matournee-fab',
        onPressed: _openImport,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Importer'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _invalider();
          if (session != null) {
            await ref.read(toursForPreparateurProvider(session.userId).future);
          }
        },
        child: asyncTours.when(
          error: (_, __) => const Center(
            child: Text('Impossible de charger vos tournées.'),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          data: (tours) {
            final filtrees = tours.where(_correspond).toList();
            int compte(_FiltreTournee f) => switch (f) {
                  _FiltreTournee.toutes => tours.length,
                  _FiltreTournee.aFaire => tours
                      .where(
                        (t) =>
                            t.statut == TourStatus.disponible ||
                            t.statut == TourStatus.telechargee,
                      )
                      .length,
                  _FiltreTournee.enCours =>
                    tours.where((t) => t.statut == TourStatus.enCours).length,
                  _FiltreTournee.terminees =>
                    tours.where((t) => t.statut == TourStatus.terminee).length,
                };

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
                AppDimensions.spacingLg,
                AppDimensions.spacingLg,
              ),
              children: [
                const Text('Mes commandes', style: AppTypography.screenTitle),
                Text(
                  '${tours.length} commande${tours.length > 1 ? 's' : ''} assignée${tours.length > 1 ? 's' : ''}',
                  style: AppTypography.secondaryLabel,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _FiltreTournee.values) ...[
                        AppFilterChip(
                          label: _libelleFiltre(f),
                          count: compte(f),
                          selected: _filtre == f,
                          onTap: () => setState(() => _filtre = f),
                        ),
                        const SizedBox(width: AppDimensions.spacingSm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                if (filtrees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spacingXl),
                    child: Center(child: Text('Aucune commande dans ce filtre.')),
                  )
                else
                  for (final tour in filtrees) ...[
                    _TourCard(
                      tour: tour,
                      isDownloading: _downloadingIds.contains(tour.id),
                      onOpen: () => _openDetail(tour),
                      onDownload: () => _download(tour),
                      onDelete: () => _confirmerSuppression(tour),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Carte "commande" de la liste — Modernisation visuelle (12/09/2026,
/// maquette v0.dev). Volontairement PAS reproduit : le nom de
/// boutique/client de la maquette ("Boutique Dakar Centre") — aucune
/// donnée de ce type n'existe dans `Tour` ni dans l'import PDF (voir
/// `Tour`, `pdf_photo_extractor.dart`) ; l'inventer aurait affiché un faux
/// nom de magasin à l'écran. `Reçue à HH:mm` (issu de `dateCreation`),
/// lui, est une vraie donnée déjà disponible.
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.tour,
    required this.isDownloading,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
  });

  final Tour tour;
  final bool isDownloading;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  String _heure(DateTime date) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = TourStatusBadge.appearanceFor(tour.statut);
    final progression = tour.nombreTotalProduits == 0
        ? 0.0
        : tour.produitsTraites / tour.nombreTotalProduits;

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(tour.numeroTournee, style: AppTypography.sectionTitle),
                  ),
                  StatusPill(label: label, background: bg, foreground: fg),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.neutral,
                    tooltip: 'Supprimer la commande',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${tour.nombreTotalProduits} produits', style: AppTypography.secondaryLabel),
                  const SizedBox(width: AppDimensions.spacingMd),
                  const Icon(Icons.schedule, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Reçue à ${_heure(tour.dateCreation)}', style: AppTypography.secondaryLabel),
                ],
              ),
              if (tour.estTeleChargeeLocalement) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tour.produitsTraites}/${tour.nombreTotalProduits} validés',
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(progression * 100).round()}%',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
                  child: LinearProgressIndicator(
                    value: progression,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceAlt,
                    color: tour.statut == TourStatus.terminee ? AppColors.success : null,
                  ),
                ),
              ],
              if (tour.statut != TourStatus.terminee) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: isDownloading
                        ? null
                        : (tour.statut == TourStatus.disponible ? onDownload : onOpen),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primary,
                    ),
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward, size: 18),
                    label: Text(
                      switch (tour.statut) {
                        TourStatus.disponible => 'Télécharger',
                        TourStatus.telechargee => 'Commencer',
                        TourStatus.enCours => 'Continuer',
                        TourStatus.terminee => '',
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
