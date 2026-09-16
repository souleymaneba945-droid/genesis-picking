import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/config/app_config.dart';
import 'package:genesis_picking/core/constants/app_constants.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/app_restart.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/profile/presentation/profile_screen.dart';
import 'package:genesis_picking/features/settings/presentation/diagnostic_screen.dart';
import 'package:genesis_picking/features/sync/presentation/sync_screen.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';
import 'package:genesis_picking/features/warehouse_location/warehouse_location_providers.dart';

/// Écran "Paramètres" — informations d'application et raccourcis.
///
/// Volontairement minimal, sans donnée fictive : version réelle de
/// l'application, environnement d'exécution réel (`AppConfig`, Module 1),
/// et raccourcis vers les écrans déjà existants (Synchronisation, Profil,
/// Diagnostic) plutôt que de dupliquer leur contenu ici.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isRefreshing = false;

  /// Force une nouvelle récupération des données depuis le serveur,
  /// immédiatement plutôt que d'attendre l'ouverture d'un écran — les
  /// comptes toujours (toutes les tournées et demandes sont créées par un
  /// compte préparateur), puis les tournées ou les demandes selon le rôle
  /// connecté. Chaque appel est déjà best-effort/borné dans le temps
  /// (voir `.timeout(...)` dans les classes `Firestore*RemoteSource`) :
  /// cette méthode ne fait qu'exécuter, une fois, ce qui tourne déjà
  /// automatiquement ailleurs.
  Future<void> _actualiser() async {
    final session = ref.read(sessionProvider);
    if (session == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await ref.read(userPullSyncProvider).pullAll();
      await ref.read(brandWarehouseLocationPullSyncProvider).pullAll();
      switch (session.role) {
        case UserRole.preparateur:
          await ref
              .read(tourServiceProvider)
              .refreshAvailableTours(session.userId);
        case UserRole.coursier:
          await ref
              .read(courierServiceProvider)
              .listRequestsForCoursier(session.userId);
        case UserRole.administrateur:
          break;
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }

    if (!mounted) return;
    AppSnackbar.showSuccess(context, 'Actualisation terminée.');
  }

  Future<void> _confirmerRedemarrage() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Redémarrer l\'application ?'),
        content: const Text(
          'L\'application va se relancer entièrement — vous devrez vous '
          'reconnecter. À utiliser si l\'appli semble bloquée. Vos '
          'données déjà enregistrées ne sont jamais perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Redémarrer'),
          ),
        ],
      ),
    );

    if (confirme == true && mounted) {
      AppRestart.restart(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final environnement = AppConfig.instance.environment.environment.name;

    // Pas de `Scaffold`/`AppBar` propre (Modernisation visuelle,
    // 12/09/2026) : cet écran est monté comme contenu d'onglet sous la
    // barre supérieure déjà fournie par `RoleShell` (Préparateur, Coursier)
    // — un AppBar ici créait une double barre. Quand l'Administrateur y
    // accède en écran séparé (`AdminHomeTab`), c'est cet appelant qui
    // fournit son propre `Scaffold`/`AppBar`, pas ce widget.
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingSm,
        AppDimensions.spacingLg,
        AppDimensions.spacingLg,
      ),
      children: [
        const Text('Paramètres', style: AppTypography.screenTitle),
        const SizedBox(height: AppDimensions.spacingLg),
        _SettingsTile(
          icon: Icons.sync_outlined,
          iconColor: AppColors.primary,
          title: 'Synchronisation',
          subtitle: 'État, dernière synchronisation',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SyncScreen()));
          },
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _SettingsTile(
          icon: Icons.person_outline,
          iconColor: AppColors.primary,
          title: 'Profil',
          subtitle: 'Informations du compte, mot de passe',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _SettingsTile(
          icon: Icons.health_and_safety_outlined,
          iconColor: AppColors.primary,
          title: 'Diagnostic',
          subtitle: 'Vitesse de connexion, état de l\'appli',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
            );
          },
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        _SettingsTile(
          icon: Icons.refresh,
          iconColor: AppColors.success,
          title: 'Actualiser',
          subtitle: 'Vérifie tout de suite s\'il y a du nouveau',
          isLoading: _isRefreshing,
          onTap: _isRefreshing ? null : _actualiser,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _SettingsTile(
          icon: Icons.restart_alt,
          iconColor: AppColors.error,
          title: 'Redémarrer l\'application',
          subtitle: 'Si l\'appli semble bloquée',
          onTap: _confirmerRedemarrage,
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        Center(
          child: Column(
            children: [
              const Text(
                AppConstants.appName,
                style: AppTypography.secondaryLabel,
              ),
              Text(
                'Version ${AppConstants.appVersion} ($environnement)',
                style: AppTypography.secondaryLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ligne de réglage — icône dans un médaillon de couleur douce, plutôt que
/// l'icône nue par défaut d'un `ListTile` (Modernisation visuelle,
/// 12/09/2026, même langage que le reste de la Refonte UI : couleur =
/// signification, jamais une simple décoration).
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.12),
                foregroundColor: iconColor,
                child: Icon(icon),
              ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
