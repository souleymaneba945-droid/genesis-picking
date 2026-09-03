import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';

/// Échelle typographique officielle.
///
/// Phase de production : la police "Inter" évoquée en fondation n'a
/// jamais été embarquée comme police d'application (aucun asset de
/// police n'existe dans ce projet) — la référencer par son nom aurait
/// silencieusement fait retomber Flutter sur la police système par
/// défaut, sans que cela soit visible dans le code. [fontFamily] est
/// donc explicitement `null` : Roboto sur Android, San Francisco sur
/// iOS — déjà moderne et parfaitement lisible, sans dépendance
/// supplémentaire ni police à embarquer. L'échelle de tailles reste
/// figée et ne doit pas être modifiée sans repasser par ce fichier.
class AppTypography {
  AppTypography._();

  static const String? fontFamily = null;

  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Nom du produit en écran de picking — l'élément le plus important à
  /// l'écran, doit être lisible d'un coup d'œil.
  static const TextStyle productName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle secondaryLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  /// Grand chiffre d'une tuile statistique de tableau de bord (Refonte UI).
  static const TextStyle statValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  /// Libellé sous un chiffre de tuile statistique, ou d'un onglet de
  /// navigation.
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Petit texte majuscule d'un chip (ex. "EMPLACEMENT", "QUANTITÉ" sur
  /// l'écran de picking).
  static const TextStyle chipLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );
}
