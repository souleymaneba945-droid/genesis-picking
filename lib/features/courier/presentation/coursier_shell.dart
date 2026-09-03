import 'package:flutter/material.dart';
import 'package:genesis_picking/core/widgets/layout/role_shell.dart';
import 'package:genesis_picking/features/courier/presentation/courier_home_screen.dart';
import 'package:genesis_picking/features/courier/presentation/coursier_home_tab.dart';
import 'package:genesis_picking/features/settings/presentation/settings_screen.dart';

/// Point d'entrée du rôle Coursier (Refonte UI) — remplace
/// `CourierHomeScreen` comme accueil de route (`AppRoutes.homeCoursier`).
///
/// 4 onglets : Accueil, Demandes (ouvertes), Historique (closes), Profil.
class CoursierShell extends StatelessWidget {
  const CoursierShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      destinations: [
        RoleDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Accueil',
          child: CoursierHomeTab(),
        ),
        RoleDestination(
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent,
          label: 'Demandes',
          child: CourierRequestsTab(historique: false),
        ),
        RoleDestination(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
          label: 'Historique',
          child: CourierRequestsTab(historique: true),
        ),
        RoleDestination(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profil',
          child: SettingsScreen(),
        ),
      ],
    );
  }
}
