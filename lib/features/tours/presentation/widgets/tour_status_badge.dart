import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Indicateur visuel de l'état d'une tournée — composant réutilisable
/// (Directive production : "les composants doivent être réutilisables"),
/// utilisé à la fois par "Mes tournées" et "Détail d'une tournée", et par
/// [PreparateurHomeTab] pour sa carte "Commande en cours"
/// ([appearanceFor] est la seule source de vérité de ce mapping — ne
/// jamais le dupliquer ailleurs).
///
/// La couleur porte l'information, jamais la décoration seule (Document
/// UX/UI).
class TourStatusBadge extends StatelessWidget {
  const TourStatusBadge({required this.statut, super.key});

  final TourStatus statut;

  /// (libellé, fond doux, couleur pleine) — Modernisation visuelle
  /// (12/09/2026) : mêmes tokens `AppColors.xxxSoft`/plein que
  /// [StatusPill] partout ailleurs dans l'app, plus de couleur codée en
  /// dur par écran.
  static (String, Color, Color) appearanceFor(TourStatus statut) {
    return switch (statut) {
      TourStatus.disponible => ('Disponible', AppColors.surfaceAlt, AppColors.textSecondary),
      TourStatus.telechargee => ('Téléchargée', AppColors.primarySoft, AppColors.primary),
      TourStatus.enCours => ('En préparation', AppColors.primarySoft, AppColors.primary),
      TourStatus.terminee => ('Terminée', AppColors.successSoft, AppColors.success),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, _, foreground) = appearanceFor(statut);
    return Tooltip(
      message: label,
      child: CircleAvatar(backgroundColor: foreground, radius: 8),
    );
  }
}

/// Version avec libellé visible (utilisée sur l'écran de détail, où
/// l'espace le permet et où la clarté prime).
class TourStatusChip extends StatelessWidget {
  const TourStatusChip({required this.statut, super.key});

  final TourStatus statut;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = TourStatusBadge.appearanceFor(statut);
    return StatusPill(label: label, background: background, foreground: foreground);
  }
}
