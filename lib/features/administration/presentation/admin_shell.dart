import 'package:flutter/material.dart';
import 'package:genesis_picking/core/widgets/layout/role_shell.dart';
import 'package:genesis_picking/features/administration/presentation/admin_courier_requests_screen.dart';
import 'package:genesis_picking/features/administration/presentation/admin_dashboard_screen.dart';
import 'package:genesis_picking/features/administration/presentation/admin_home_tab.dart';
import 'package:genesis_picking/features/user_management/presentation/user_management_screen.dart';

/// Point d'entrée du rôle Administrateur (Refonte UI) — remplace
/// `AdminDashboardScreen` comme accueil de route
/// (`AppRoutes.homeAdministrateur`).
///
/// 4 onglets : Tableau de bord, Tournées, Utilisateurs, Suivi.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      destinations: [
        RoleDestination(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Tableau de bord',
          child: AdminHomeTab(),
        ),
        RoleDestination(
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          label: 'Tournées',
          child: AdminDashboardScreen(),
        ),
        RoleDestination(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Utilisateurs',
          child: UserManagementScreen(),
        ),
        RoleDestination(
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent,
          label: 'Suivi',
          child: AdminCourierRequestsScreen(),
        ),
      ],
    );
  }
}
