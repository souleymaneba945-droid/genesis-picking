import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/import/presentation/import_tour_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:genesis_picking/features/tours/presentation/tour_detail_screen.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_action_button.dart';
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

class _MyToursScreenState extends ConsumerState<MyToursScreen> {
  final Set<String> _downloadingIds = {};

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
            if (tours.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: AppDimensions.spacingXl),
                  Center(child: Text('Aucune tournée pour le moment.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
                AppDimensions.spacingLg,
                AppDimensions.spacingLg,
              ),
              itemCount: tours.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimensions.spacingSm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Text('Ma tournée',
                      style: AppTypography.screenTitle);
                }
                final tour = tours[index - 1];
                final isDownloading = _downloadingIds.contains(tour.id);
                return Card(
                  child: InkWell(
                    onTap: () => _openDetail(tour),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.cornerRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.cardPadding),
                      child: Row(
                        children: [
                          TourStatusBadge(statut: tour.statut),
                          const SizedBox(width: AppDimensions.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tour.numeroTournee,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tour.estTeleChargeeLocalement
                                      ? '${tour.produitsTraites}/${tour.nombreTotalProduits} produits traités'
                                      : 'Pas encore téléchargée',
                                  style: AppTypography.secondaryLabel,
                                ),
                              ],
                            ),
                          ),
                          TourActionButton(
                            tour: tour,
                            isLoading: isDownloading,
                            compact: true,
                            onDownload: () => _download(tour),
                            onStartOrResume: () => _openDetail(tour),
                          ),
                          IconButton(
                            onPressed: () => _confirmerSuppression(tour),
                            icon: const Icon(Icons.delete_outline),
                            color: AppColors.neutral,
                            tooltip: 'Supprimer la tournée',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
