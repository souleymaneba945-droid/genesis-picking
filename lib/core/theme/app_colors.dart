import 'package:flutter/widgets.dart';

/// Palette de couleurs officielle de GENESIS PICKING.
///
/// Reprend exactement la palette validée dans le Document UX/UI. Chaque
/// couleur porte un sens métier constant dans toute l'application — ne
/// jamais réutiliser [success] ou [error] pour une simple décoration.
///
/// Modernisation visuelle (12-13/09/2026) : valeurs alignées sur les
/// jetons de design source. Deux passes : d'abord `globals.css` du
/// prototype v0.dev `genesis-picking-wa` (tokens OKLCH shadcn/ui,
/// convertis en sRGB par calcul) puis, le 13/09/2026, un document de
/// design system fourni directement par l'utilisateur (mêmes valeurs de
/// marque, [success]/[error]/[textPrimary] légèrement ajustés vers des
/// teintes plus vives) — ce second document prévaut là où les deux
/// divergent, étant la version la plus récente et la plus explicite. Voir
/// mémoire `v0-design-modernization` pour le contexte (prototype
/// React/Tailwind de référence, jamais du code exécuté dans cette app).
class AppColors {
  AppColors._();

  /// Couleur principale (marque), utilisée pour les actions principales
  /// et les en-têtes. Source : `--primary: oklch(0.52 0.16 258)`.
  static const Color primary = Color(0xFF2466C3);

  /// Succès / validé : produit trouvé, livraison confirmée, tournée
  /// clôturée. Source : document de design system du 13/09/2026.
  static const Color success = Color(0xFF16A34A);

  /// Attention / anomalie : quantité modifiée, retard. Source :
  /// `--warning: oklch(0.76 0.15 75)`.
  static const Color warning = Color(0xFFE8A127);

  /// Variante plus soutenue de [warning], utilisée uniquement comme
  /// couleur de TEXTE sur fond [warningSoft] ("En attente", alerte
  /// coursier) — l'ambre plein de [warning] n'offre pas assez de contraste
  /// pour du texte, seulement pour une icône. Source :
  /// `--warning-foreground: oklch(0.28 0.05 75)` (arrondi source réel :
  /// badge ambre du prototype, oklch(0.45 0.09 75)).
  static const Color warningText = Color(0xFF724D0B);

  /// Erreur / bloquant : rupture de stock, échec de livraison, erreur de
  /// connexion. Source : document de design system du 13/09/2026.
  static const Color error = Color(0xFFDC2626);

  /// Neutre / en attente : statuts "à faire", non commencé. Source :
  /// `--muted-foreground: oklch(0.52 0.02 258)`.
  static const Color neutral = Color(0xFF626A75);

  /// Fond principal de l'application. Source : document de design system
  /// du 13/09/2026 (quasi identique au calcul OKLCH précédent).
  static const Color background = Color(0xFFF5F7FA);

  /// Source : `--card: oklch(1 0 0)`.
  static const Color surface = Color(0xFFFFFFFF);

  /// Source : document de design system du 13/09/2026.
  static const Color textPrimary = Color(0xFF1E2A3A);
  static const Color textSecondary = neutral;

  /// Fond légèrement teinté pour distinguer une carte/section du fond
  /// principal sans tracer de bordure dure (Refonte UI — "épurée, sans
  /// bordures partout"). Source : `--muted`/`--secondary`.
  static const Color surfaceAlt = Color(0xFFECF1F5);

  /// Séparateur discret, utilisé à la place d'une bordure pleine. Source :
  /// `--border: oklch(0.9 0.008 258)`.
  static const Color divider = Color(0xFFDBDEE3);

  /// Teinte douce de [primary], pour un fond de badge/chip/icône —
  /// jamais pour du texte ni une action (voir règle en tête de fichier).
  /// Source : le prototype ne fixe pas de hex séparé, il applique
  /// `bg-primary/10` (10% d'opacité) — valeur ici précalculée (mélange
  /// sur fond blanc) pour rester une `Color` constante, jamais recalculée
  /// à l'exécution.
  static const Color primarySoft = Color(0xFFE9F0F9);

  /// Teinte douce de [success]/[warning]/[error], pour le fond d'un badge
  /// de statut ("En préparation", "En attente", "Introuvable") — le texte
  /// du badge reste dans la couleur pleine correspondante, jamais dans sa
  /// version douce. Sources : `bg-success/12`, `bg-warning/15`,
  /// `bg-destructive/12`, précalculées comme [primarySoft].
  static const Color successSoft = Color(0xFFE3F4E9);
  static const Color warningSoft = Color(0xFFFCF1DF);
  static const Color errorSoft = Color(0xFFFBE5E5);
}
