import 'package:flutter/material.dart';
import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';

/// Icône et couleur associées à un [ActivityLevel] — un seul endroit pour
/// cette correspondance, réutilisé par la carte "Activité récente" et par
/// l'écran d'historique complet, pour qu'elles ne divergent jamais.
extension ActivityLevelStyle on ActivityLevel {
  IconData get icone => switch (this) {
        ActivityLevel.succes => Icons.check_circle_outline,
        ActivityLevel.avertissement => Icons.error_outline,
        ActivityLevel.neutre => Icons.info_outline,
      };

  Color get couleur => switch (this) {
        ActivityLevel.succes => AppColors.success,
        ActivityLevel.avertissement => AppColors.warning,
        ActivityLevel.neutre => AppColors.neutral,
      };
}
