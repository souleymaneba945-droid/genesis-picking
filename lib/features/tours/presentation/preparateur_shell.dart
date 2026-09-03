import 'package:flutter/material.dart';
import 'package:genesis_picking/core/widgets/layout/role_shell.dart';
import 'package:genesis_picking/features/courier/presentation/my_courier_requests_screen.dart';
import 'package:genesis_picking/features/profile/presentation/profile_screen.dart';
import 'package:genesis_picking/features/tours/presentation/my_tours_screen.dart';
import 'package:genesis_picking/features/tours/presentation/preparateur_home_tab.dart';

/// Point d'entrée du rôle Préparateur (Refonte UI) — remplace
/// `MyToursScreen` comme accueil de route (`AppRoutes.homePreparateur`).
///
/// 4 onglets : Accueil (tournée active), Ma tournée (liste complète),
/// Vérifications (suivi des demandes coursier), Profil.
class PreparateurShell extends StatelessWidget {
  const PreparateurShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      destinations: [
        RoleDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Accueil',
          child: PreparateurHomeTab(),
        ),
        RoleDestination(
          icon: Icons.checklist_outlined,
          selectedIcon: Icons.checklist,
          label: 'Ma tournée',
          child: MyToursScreen(),
        ),
        RoleDestination(
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent,
          label: 'Vérifications',
          child: MyCourierRequestsScreen(),
        ),
        RoleDestination(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profil',
          child: ProfileScreen(),
        ),
      ],
    );
  }
}
