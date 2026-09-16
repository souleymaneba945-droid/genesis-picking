import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';

/// Pastille de filtre horizontale ("Tous 4", "Restants 3"...) —
/// Modernisation visuelle (13/09/2026, maquette v0.dev) : partagée entre
/// tous les écrans à filtres (liste de picking, Mes commandes) plutôt que
/// dupliquée, pour que le même geste ait toujours le même rendu.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

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
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
