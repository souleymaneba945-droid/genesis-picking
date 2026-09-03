import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Indicateur visuel de l'état d'une tournée — composant réutilisable
/// (Directive production : "les composants doivent être réutilisables"),
/// utilisé à la fois par "Mes tournées" et "Détail d'une tournée".
///
/// La couleur porte l'information, jamais la décoration seule (Document
/// UX/UI).
class TourStatusBadge extends StatelessWidget {
  const TourStatusBadge({required this.statut, super.key});

  final TourStatus statut;

  static (String, Color) appearanceFor(TourStatus statut) {
    return switch (statut) {
      TourStatus.disponible => ('Disponible', AppColors.neutral),
      TourStatus.telechargee => ('Téléchargée', AppColors.warning),
      TourStatus.enCours => ('En cours', AppColors.primary),
      TourStatus.terminee => ('Terminée', AppColors.success),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = appearanceFor(statut);
    return Tooltip(
      message: label,
      child: CircleAvatar(backgroundColor: color, radius: 8),
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
    final (label, color) = TourStatusBadge.appearanceFor(statut);
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide.none,
    );
  }
}
