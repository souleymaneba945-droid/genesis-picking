import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/activity/recent_activity_card.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/features/picking/presentation/picking_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_action_button.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

/// Onglet "Accueil" du Préparateur (Refonte UI).
///
/// Salue le préparateur et met en avant SA tournée active dans une carte
/// unique, très visuelle — l'écran que le préparateur voit en premier en
/// arrivant, avant même de choisir quoi que ce soit. La liste complète des
/// tournées (s'il y en a plusieurs) reste dans l'onglet "Ma tournée".
///
/// Source de donnée : [toursForPreparateurProvider] — même flux "en
/// direct" partagé que [MyToursScreen] (voir ce provider) : les deux
/// onglets restent automatiquement synchronisés entre eux.
class PreparateurHomeTab extends ConsumerStatefulWidget {
  const PreparateurHomeTab({super.key});

  @override
  ConsumerState<PreparateurHomeTab> createState() => _PreparateurHomeTabState();
}

class _PreparateurHomeTabState extends ConsumerState<PreparateurHomeTab> {
  bool _isDownloading = false;

  /// À appeler après toute écriture LOCALE (téléchargement) qui ne serait
  /// pas automatiquement reflétée par le flux distant — voir la même note
  /// dans `MyToursScreen`.
  void _invalider() {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    ref.invalidate(toursForPreparateurProvider(session.userId));
  }

  /// La tournée à mettre en avant : en cours en priorité, puis
  /// téléchargée, puis disponible — jamais une tournée déjà terminée.
  Tour? _tourActive(List<Tour> tours) {
    for (final statut in [
      TourStatus.enCours,
      TourStatus.telechargee,
      TourStatus.disponible,
    ]) {
      for (final tour in tours) {
        if (tour.statut == statut) return tour;
      }
    }
    return null;
  }

  Future<void> _download(Tour tour) async {
    setState(() => _isDownloading = true);
    final result = await ref.read(tourServiceProvider).downloadTour(tour.id);
    if (!mounted) return;
    setState(() => _isDownloading = false);
    result.when(
      success: (_) => _invalider(),
      failure: (exception) =>
          AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception)),
    );
  }

  void _startOrResume(Tour tour) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PickingScreen(tourId: tour.id)))
        .then((_) => _invalider());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final asyncTours = session == null
        ? const AsyncValue<List<Tour>>.data([])
        : ref.watch(toursForPreparateurProvider(session.userId));

    return RefreshIndicator(
      onRefresh: () async {
        _invalider();
        if (session != null) {
          await ref.read(toursForPreparateurProvider(session.userId).future);
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingLg,
          AppDimensions.spacingSm,
          AppDimensions.spacingLg,
          AppDimensions.spacingLg,
        ),
        children: [
          Text(
            'Bonjour ${session?.displayName ?? ''}',
            style: AppTypography.screenTitle,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          asyncTours.when(
            error: (_, __) => const _EmptyCard(
              message: 'Impossible de charger votre tournée.',
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            data: (tours) {
              final tour = _tourActive(tours);
              if (tour == null) {
                return const _EmptyCard(
                  message: 'Aucune tournée pour le moment.',
                );
              }
              return _ActiveTourCard(
                tour: tour,
                isLoading: _isDownloading,
                onDownload: () => _download(tour),
                onStartOrResume: () => _startOrResume(tour),
              );
            },
          ),
          if (session != null) ...[
            const SizedBox(height: AppDimensions.spacingLg),
            RecentActivityCard(userId: session.userId),
          ],
        ],
      ),
    );
  }
}

class _ActiveTourCard extends StatelessWidget {
  const _ActiveTourCard({
    required this.tour,
    required this.isLoading,
    required this.onDownload,
    required this.onStartOrResume,
  });

  final Tour tour;
  final bool isLoading;
  final VoidCallback onDownload;
  final VoidCallback onStartOrResume;

  @override
  Widget build(BuildContext context) {
    final progression = tour.nombreTotalProduits == 0
        ? 0.0
        : tour.produitsTraites / tour.nombreTotalProduits;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ma tournée',
              style: AppTypography.chipLabel.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(tour.numeroTournee, style: AppTypography.screenTitle),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${tour.nombreTotalProduits} produits',
              style: AppTypography.secondaryLabel,
            ),
            if (tour.estTeleChargeeLocalement) ...[
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                '${tour.produitsTraites} / ${tour.nombreTotalProduits} collectés',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
                child: LinearProgressIndicator(value: progression, minHeight: 10),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLg),
            TourActionButton(
              tour: tour,
              isLoading: isLoading,
              onDownload: onDownload,
              onStartOrResume: onStartOrResume,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Center(
          child: Text(
            message,
            style: AppTypography.secondaryLabel,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
