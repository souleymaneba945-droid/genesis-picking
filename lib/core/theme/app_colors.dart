import 'package:flutter/widgets.dart';

/// Palette de couleurs officielle de GENESIS PICKING.
///
/// Reprend exactement la palette validée dans le Document UX/UI. Chaque
/// couleur porte un sens métier constant dans toute l'application — ne
/// jamais réutiliser [success] ou [error] pour une simple décoration.
class AppColors {
  AppColors._();

  /// Couleur principale (marque), utilisée pour les actions principales
  /// et les en-têtes.
  static const Color primary = Color(0xFF0B3D91);

  /// Succès / validé : produit trouvé, livraison confirmée, tournée
  /// clôturée.
  static const Color success = Color(0xFF2E7D32);

  /// Attention / anomalie : quantité modifiée, retard.
  static const Color warning = Color(0xFFF59E0B);

  /// Erreur / bloquant : rupture de stock, échec de livraison, erreur de
  /// connexion.
  static const Color error = Color(0xFFD32F2F);

  /// Neutre / en attente : statuts "à faire", non commencé.
  static const Color neutral = Color(0xFF6B7280);

  /// Fond principal de l'application.
  static const Color background = Color(0xFFF8F9FA);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = neutral;

  /// Fond légèrement teinté pour distinguer une carte/section du fond
  /// principal sans tracer de bordure dure (Refonte UI — "épurée, sans
  /// bordures partout").
  static const Color surfaceAlt = Color(0xFFF1F3F5);

  /// Séparateur discret, utilisé à la place d'une bordure pleine.
  static const Color divider = Color(0xFFE9ECEF);

  /// Teinte douce de [primary], pour un fond de badge/chip/icône —
  /// jamais pour du texte ni une action (voir règle en tête de fichier).
  static const Color primarySoft = Color(0xFFE7EDF8);
}
