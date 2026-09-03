import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

/// Vue de fin de tournée — affichée quand tous les produits ont un état
/// final. Se contente de proposer la clôture (Module 3,
/// `TourService.completeTour`) ; aucune nouvelle logique métier ici.
///
/// Extrait de `picking_screen.dart` au Module 9 (Stabilisation) — aucun
/// changement de comportement.
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
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 64),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Tous les produits ont été traités '
            '(${session.progression.traites}/${session.progression.total}).',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
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
    );
  }
}
