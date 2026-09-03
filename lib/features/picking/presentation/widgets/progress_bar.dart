import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';

/// Barre de progression — exactement les trois informations demandées
/// par la Directive Module 4 : produits traités, total, pourcentage.
///
/// Extrait de `picking_screen.dart` au Module 9 (Stabilisation) pour
/// garder chaque fichier de présentation focalisé sur un seul widget —
/// aucun changement de comportement.
class ProgressBar extends StatelessWidget {
  const ProgressBar({required this.progression, super.key});

  final PickingProgress progression;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${progression.traites}/${progression.total} produits · '
          '${(progression.pourcentage * 100).round()}%',
          style: AppTypography.secondaryLabel,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        LinearProgressIndicator(value: progression.pourcentage),
      ],
    );
  }
}
