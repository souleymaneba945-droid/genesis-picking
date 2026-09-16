import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';

/// Badge de statut arrondi ("En attente", "En préparation", "Introuvable")
/// — Modernisation visuelle (12/09/2026, maquettes v0.dev). Toujours un
/// fond doux (`AppColors.xxxSoft`) et un texte dans la couleur pleine
/// correspondante, jamais l'inverse : c'est ce qui garde le badge lisible
/// sans jamais crier plus fort qu'un bouton d'action.
///
/// Remplace les badges codés en dur écran par écran par un seul widget
/// partagé, conformément à la convention du fichier thème centralisé.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    super.key,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
