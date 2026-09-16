import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/branding/app_logo_mark.dart';
import 'package:genesis_picking/core/widgets/branding/initials_avatar.dart';
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
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
              ),
              child: Row(
                children: [
                  AppLogoMark(size: 32),
                  SizedBox(width: AppDimensions.spacingSm),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'GENESIS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '  PICKING',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  SyncStatusIndicator(),
                  SizedBox(width: AppDimensions.spacingMd),
                  _AccountMenu(),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (final d in widget.destinations)
                    // Marge basse commune à TOUS les onglets (12/09/2026,
                    // retour terrain : le dernier élément d'une liste
                    // arrivait flush contre la barre de navigation, sur
                    // certains téléphones visuellement fondu avec la barre
                    // système de l'appareil — inaccessible en pratique).
                    // Centralisée ici plutôt que dans chaque écran
                    // d'onglet : elle s'applique à `MyToursScreen`,
                    // `MyCourierRequestsScreen`, `UserManagementScreen`,
                    // etc. sans toucher un seul de ces fichiers. Une
                    // simple marge, jamais un `SafeArea` : celui-ci est
                    // déjà couvert par `NavigationBar` lui-même
                    // (voir sa documentation — la marge système est
                    // ajoutée à sa hauteur automatiquement).
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.spacingLg,
                      ),
                      child: d.child,
                    ),
                ],
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

/// Avatar + menu de compte de la barre supérieure (Modernisation visuelle,
/// 12/09/2026) — un seul point d'accès à la déconnexion, quel que soit le
/// rôle (l'onglet "Profil" n'existe pas forcément dans chaque
/// [RoleShell] — voir `AdminShell`, qui n'en a pas). Reprend exactement le
/// même appel que le bouton "Se déconnecter" existant de
/// `ProfileScreen` : fermer la session suffit, la redirection vers
/// `/login` suit déjà automatiquement (`app_router.dart`).
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final nom = session?.displayName ?? '?';

    return PopupMenuButton<void>(
      padding: EdgeInsets.zero,
      offset: const Offset(0, 44),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => ref.read(sessionProvider.notifier).close(),
          child: const Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.error),
              SizedBox(width: AppDimensions.spacingSm),
              Text('Se déconnecter'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialsAvatar(name: nom),
          const Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}
