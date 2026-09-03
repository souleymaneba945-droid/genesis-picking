/// Espacements et tailles standard, pour ne jamais coder de valeur "en dur"
/// dans un écran (Document UX/UI : marges généreuses, cibles tactiles
/// larges, utilisation à une main).
class AppDimensions {
  AppDimensions._();

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  /// Hauteur des boutons d'action principaux. Portée à 64dp en phase de
  /// production (Directive : "très grands boutons", usage à une main,
  /// entrepôt) — au-delà du minimum Material (48dp).
  static const double primaryButtonHeight = 64;
  static const double minTapTargetSize = 48;

  static const double cornerRadius = 14;

  /// Rayon des grandes cartes héros (tableau de bord, carte produit de
  /// l'écran de picking) — Refonte UI, plus visuel que [cornerRadius].
  static const double cornerRadiusLg = 24;

  /// Marge intérieure standard d'une carte de tableau de bord.
  static const double cardPadding = 20;
}
