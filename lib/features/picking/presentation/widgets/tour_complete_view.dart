import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/status/stat_card.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

/// Vue de fin de tournée — affichée quand tous les produits ont un état
/// final. Se contente de proposer la clôture (Module 3,
/// `TourService.completeTour`) ; aucune nouvelle logique métier ici.
///
/// Modernisation visuelle (13/09/2026, maquette v0.dev
/// `picking-screen.tsx`/`PickingComplete`) : médaillon de succès, chiffres
/// réels validés/introuvables (calculés sur [session.produits], jamais
/// inventés), et un second bouton de sortie — repris tel quel, sauf le
/// nom du client (fictif dans la maquette source, absent de nos données
/// réelles, voir mémoire `v0-design-modernization`).
class TourCompleteView extends ConsumerWidget {
  const TourCompleteView({
    required this.tourId,
    required this.session,
    super.key,
  });

  final String tourId;
  final PickingSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valides = session.produits
        .where(
          (p) =>
              p.etat == ProductState.collecte ||
              p.etat == ProductState.partiellementCollecte,
        )
        .length;
    final introuvables = session.produits
        .where(
          (p) =>
              p.etat == ProductState.introuvable ||
              p.etat == ProductState.envoyeAuCoursier,
        )
        .length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
              ),
              child: const Icon(Icons.celebration_outlined, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            const Text(
              'Commande préparée !',
              style: AppTypography.screenTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${session.tour.numeroTournee} a été traitée '
              '(${session.progression.traites}/${session.progression.total} produits).',
              textAlign: TextAlign.center,
              style: AppTypography.secondaryLabel,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Row(
              children: [
                Expanded(
                  child: StatCard(value: '$valides', label: 'Validés', color: AppColors.success),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: StatCard(value: '$introuvables', label: 'Introuvables', color: AppColors.error),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            PrimaryButton(
              label: 'Clôturer la tournée',
              onPressed: () async {
                final result = await ref
                    .read(tourServiceProvider)
                    .completeTour(tourId);
                if (!context.mounted) return;
                result.when(
                  success: (_) => Navigator.of(context).pop(),
                  failure: (exception) => AppSnackbar.showError(
                    context,
                    ErrorHandler.userMessageFor(exception),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
