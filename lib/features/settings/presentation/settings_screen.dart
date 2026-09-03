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

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync_outlined),
              title: const Text('Synchronisation'),
              subtitle: const Text('État, dernière synchronisation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SyncScreen()));
              },
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil'),
              subtitle: const Text('Informations du compte, mot de passe'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Diagnostic'),
              subtitle: const Text('Vitesse de connexion, état de l\'appli'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Card(
            child: ListTile(
              leading: _isRefreshing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              title: const Text('Actualiser'),
              subtitle: const Text('Vérifie tout de suite s\'il y a du nouveau'),
              onTap: _isRefreshing ? null : _actualiser,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restart_alt, color: AppColors.error),
              title: const Text('Redémarrer l\'application'),
              subtitle: const Text('Si l\'appli semble bloquée'),
              onTap: _confirmerRedemarrage,
            ),
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
      ),
    );
  }
}
