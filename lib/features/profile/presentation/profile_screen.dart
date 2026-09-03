import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/buttons/secondary_button.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/sync/presentation/sync_screen.dart';
import 'package:genesis_picking/features/user_management/presentation/reset_password_dialog.dart';

/// Onglet "Profil" — informations du compte connecté (Refonte UI).
///
/// Partagé tel quel entre les 3 rôles (Préparateur, Coursier, Administrateur)
/// — même contenu, même onglet. Volontairement minimal : nom, identifiant,
/// rôle, accès à la synchronisation, et la seule action qui a du sens ici —
/// changer son propre mot de passe. Réutilise [ResetPasswordDialog], déjà
/// construit et validé pour l'Administrateur (Module 2).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    if (session == null) {
      return const Center(child: Text('Aucune session active.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingSm,
        AppDimensions.spacingLg,
        AppDimensions.spacingLg,
      ),
      children: [
        const Text('Profil', style: AppTypography.screenTitle),
        const SizedBox(height: AppDimensions.spacingLg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.cardPadding),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.person, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  session.displayName,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  _roleLabel(session.role),
                  style: AppTypography.secondaryLabel,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync_outlined, color: AppColors.primary),
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
        const SizedBox(height: AppDimensions.spacingLg),
        SecondaryButton(
          label: 'Changer mon mot de passe',
          onPressed: () => _openResetPassword(context, ref),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        SecondaryButton(
          label: 'Se déconnecter',
          onPressed: () => ref.read(sessionProvider.notifier).close(),
        ),
      ],
    );
  }

  Future<void> _openResetPassword(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;

    final users = await ref.read(userRepositoryProvider).listAll();
    UserAccount? compte;
    for (final user in users) {
      if (user.id == session.userId) {
        compte = user;
        break;
      }
    }
    if (compte == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => ResetPasswordDialog(user: compte!),
    );
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.administrateur => 'Administrateur',
      UserRole.preparateur => 'Préparateur',
      UserRole.coursier => 'Coursier',
    };
  }
}
