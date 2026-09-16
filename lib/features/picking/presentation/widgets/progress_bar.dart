import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';

/// Barre de progression — exactement les trois informations demandées
/// par la Directive Module 4 : produits traités, total, pourcentage.
///
/// Extrait de `picking_screen.dart` au Module 9 (Stabilisation) pour
/// garder chaque fichier de présentation focalisé sur un seul widget —
/// aucun changement de comportement.
///
/// Modernisation visuelle (12/09/2026) : piste arrondie et plus épaisse,
/// même langage que le reste de la Refonte UI — toujours une seule barre
/// continue (jamais segmentée par produit : avec des tournées de
/// plusieurs dizaines de produits, des segments individuels deviendraient
/// illisibles).
class ProgressBar extends StatelessWidget {
  const ProgressBar({required this.progression, super.key});

  final PickingProgress progression;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${progression.traites}/${progression.total} produits',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${(progression.pourcentage * 100).round()}%',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
          child: LinearProgressIndicator(
            value: progression.pourcentage,
            minHeight: 10,
            backgroundColor: AppColors.surfaceAlt,
          ),
        ),
      ],
    );
  }
}
