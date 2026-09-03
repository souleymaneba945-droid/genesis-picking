import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/status/sync_status_indicator.dart';

/// Un onglet de [RoleShell] : icône, libellé, contenu.
///
/// Volontairement une simple structure de données — [RoleShell] ne connaît
/// rien du contenu de chaque onglet, seulement comment le présenter.
class RoleDestination {
  const RoleDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget child;
}

/// Coquille de navigation par onglets, commune aux 3 rôles (Refonte UI).
///
/// Remplace les anciens écrans d'accueil à AppBar bleue pleine largeur +
/// actions en icônes : un unique `Scaffold` avec une barre supérieure
/// minimale (juste la marque et l'indicateur de synchronisation — toujours
/// visible, jamais un menu) et une barre de navigation Material 3 en bas,
/// adaptée à un usage à une main. Le contenu de chaque onglet est préservé
/// via `IndexedStack` : changer d'onglet ne recharge jamais les données déjà
/// affichées d'un autre onglet.
class RoleShell extends StatefulWidget {
  const RoleShell({required this.destinations, super.key, this.initialIndex = 0});

  final List<RoleDestination> destinations;
  final int initialIndex;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
              ),
              child: Row(
                children: [
                  Text(
                    'GENESIS PICKING',
                    style: AppTypography.navLabel.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  const SyncStatusIndicator(),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [for (final d in widget.destinations) d.child],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final d in widget.destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
