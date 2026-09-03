import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';

/// Tuile "chiffre + libellé" d'un tableau de bord (Refonte UI).
///
/// Réutilisée telle quelle par les 3 tableaux de bord (Préparateur, Coursier,
/// Administrateur) plutôt que dupliquée trois fois — seul ce qu'affiche
/// chaque tuile change, jamais sa forme.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.value,
    required this.label,
    super.key,
    this.icon,
    this.color = AppColors.primary,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 22),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
              Text(value, style: AppTypography.statValue.copyWith(color: color)),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(label, style: AppTypography.secondaryLabel),
            ],
          ),
        ),
      ),
    );
  }
}
