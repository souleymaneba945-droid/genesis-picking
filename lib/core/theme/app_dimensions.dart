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

  /// Rayon standard d'une carte (Refonte UI). Modernisation visuelle :
  /// 16, valeur du document de design system fourni par l'utilisateur le
  /// 13/09/2026 (remplace le 22 calculé la veille depuis le prototype
  /// v0.dev — ce document, plus récent et explicite, prévaut).
  static const double cornerRadius = 16;

  /// Rayon des toutes plus grandes surfaces (carte de connexion) — source :
  /// `rounded-3xl`, seule valeur de la maquette PAS remappée par le thème
  /// (reste le 24 par défaut de Tailwind, un cran au-dessus de
  /// [cornerRadius]).
  static const double cornerRadiusLg = 24;

  /// Rayon d'un bouton ou d'un champ de saisie — source : `rounded-xl`
  /// (`var(--radius) + 4px` = 18).
  static const double cornerRadiusMd = 18;

  /// Rayon d'une petite tuile interne à une carte — source : `rounded-md`
  /// (`var(--radius) - 2px` = 12).
  static const double cornerRadiusSm = 12;

  /// Rayon "pilule" d'un badge de statut, toujours égal ou supérieur à la
  /// moitié de sa hauteur pour rester parfaitement arrondi quel que soit
  /// son contenu.
  static const double cornerRadiusPill = 999;

  /// Marge intérieure standard d'une carte de tableau de bord.
  static const double cardPadding = 20;
}
