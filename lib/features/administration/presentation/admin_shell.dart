import 'package:flutter/material.dart';
import 'package:genesis_picking/core/widgets/layout/role_shell.dart';
import 'package:genesis_picking/features/administration/presentation/admin_courier_requests_screen.dart';
import 'package:genesis_picking/features/administration/presentation/admin_dashboard_screen.dart';
import 'package:genesis_picking/features/administration/presentation/admin_demand_stats_screen.dart';
import 'package:genesis_picking/features/administration/presentation/admin_home_tab.dart';
import 'package:genesis_picking/features/user_management/presentation/user_management_screen.dart';
import 'package:genesis_picking/features/warehouse_location/presentation/warehouse_location_management_screen.dart';

/// Point d'entrée du rôle Administrateur (Refonte UI) — remplace
/// `AdminDashboardScreen` comme accueil de route
/// (`AppRoutes.homeAdministrateur`).
///
/// 6 onglets : Tableau de bord, Tournées, Utilisateurs, Emplacements, Suivi,
/// Statistiques. "Emplacements" (13/09/2026) puis "Statistiques"
/// (16/09/2026) promus en onglets à part entière — même retour terrain les
/// deux fois : un accès caché derrière une icône passait inaperçu. La règle
/// "4 onglets max par rôle" observée ailleurs (`PreparateurShell`,
/// `CoursierShell`) reste assumée comme non applicable à ce rôle.
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
          icon: Icons.warehouse_outlined,
          selectedIcon: Icons.warehouse,
          label: 'Emplacements',
          child: WarehouseLocationManagementScreen(),
        ),
        RoleDestination(
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent,
          label: 'Suivi',
          child: AdminCourierRequestsScreen(),
        ),
        RoleDestination(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Statistiques',
          child: AdminDemandStatsScreen(),
        ),
      ],
    );
  }
}
