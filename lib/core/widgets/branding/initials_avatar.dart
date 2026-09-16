import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';

/// Avatar rond aux initiales de l'utilisateur ("Souleymane Ba" → "SB") —
/// Modernisation visuelle (12/09/2026, maquettes v0.dev), utilisé dans la
/// barre supérieure de [RoleShell] à la place d'un simple bouton menu.
///
/// Extrait des deux premières initiales de mots distincts uniquement
/// (jamais deux lettres d'un même mot) : un nom d'un seul mot donne donc
/// une seule lettre, plutôt qu'une abréviation trompeuse.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({required this.name, super.key, this.radius = 18});

  final String name;
  final double radius;

  String get _initiales {
    final mots = name.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    final lettres = mots.take(2).map((m) => m[0].toUpperCase());
    final resultat = lettres.join();
    return resultat.isEmpty ? '?' : resultat;
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      child: Text(
        _initiales,
        // Proportionnelle au rayon : la même valeur fixe convenait à la
        // barre supérieure (rayon 18) mais paraissait minuscule sur le
        // grand avatar de l'écran Profil (rayon 36).
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.75),
      ),
    );
  }
}
