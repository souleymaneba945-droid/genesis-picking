import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';

/// Thème global unique de l'application.
///
/// Un seul [ThemeData] pour toute l'application : aucun écran ne doit
/// définir ses propres couleurs ou styles de bouton en dehors de ce
/// fichier et de `app_colors.dart` / `app_typography.dart`.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      fontFamily: AppTypography.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(
            AppDimensions.primaryButtonHeight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
          ),
          textStyle: AppTypography.buttonLabel,
        ),
      ),
      // Modernisation visuelle (12/09/2026) : sans ce thème explicite, un
      // FAB prend par défaut la couleur "tertiary" dérivée de la seed —
      // un violet ne portant aucun sens métier, jamais utilisé nulle part
      // ailleurs dans l'app (repéré sur "Ma tournée"/"Importer").
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(
            AppDimensions.primaryButtonHeight,
          ),
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
          ),
          textStyle: AppTypography.buttonLabel,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      // Modernisation visuelle (13/09/2026) : un seul thème pour TOUS les
      // champs de saisie de l'app (`TextField`/`TextFormField`/
      // `DropdownButtonFormField`) — fond `background`, bordure fine
      // `divider`, bordure `primary` au focus, coins arrondis
      // [AppDimensions.cornerRadiusMd] — plutôt que de retoucher chaque
      // écran de formulaire un par un (`CreateUserScreen`,
      // `RenameIdentifiantDialog`, `CreateBrandLocationScreen`...).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      // Refonte UI — cartes sans bordure dure, ombre très légère, coins
      // largement arrondis : c'est ce qui remplace visuellement les
      // `ListTile`/`Card` par défaut sur les écrans principaux.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      // Barre de navigation du bas — un jeu par rôle (Préparateur, Coursier,
      // Administrateur), tous construits sur ce même thème.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.navLabel.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
      ),
    );
  }
}
