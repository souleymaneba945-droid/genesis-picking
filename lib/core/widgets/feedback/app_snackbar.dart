import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';

/// Point d'entrée unique pour afficher un message court à l'utilisateur.
///
/// Les textes eux-mêmes viennent toujours de [AppLocalizations] ou des
/// messages validés dans le PRD (chapitre 9) — cette classe ne gère que
/// l'apparence, jamais le contenu des textes.
class AppSnackbar {
  AppSnackbar._();

  static void showInfo(BuildContext context, String message) {
    _show(context, message, backgroundColor: AppColors.neutral);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, backgroundColor: AppColors.success);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, backgroundColor: AppColors.error);
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
  }
}
