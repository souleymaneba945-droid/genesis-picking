import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/user_management/presentation/create_user_screen.dart';
import 'package:genesis_picking/features/user_management/presentation/reset_password_dialog.dart';

/// Onglet "Utilisateurs" de l'Administrateur (Refonte UI) — écran 4.14 du
/// Cahier des charges : gestion des comptes.
///
/// Actions couvertes : créer un compte, désactiver/réactiver, réinitialiser
/// un mot de passe — exactement le périmètre défini pour ce rôle.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  late Future<List<UserAccount>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<UserAccount>> _loadUsers() {
    return ref.read(userRepositoryProvider).listAll();
  }

  void _refresh() {
    setState(() => _usersFuture = _loadUsers());
  }

  Future<void> _toggleActive(UserAccount user) async {
    final repository = ref.read(userRepositoryProvider);
    final result = await repository.setActive(
      userId: user.id,
      actif: !user.actif,
    );
    if (!mounted) return;
    result.when(
      success: (_) {
        _refresh();
        AppSnackbar.showSuccess(
          context,
          user.actif ? 'Compte désactivé.' : 'Compte réactivé.',
        );
      },
      failure: (exception) =>
          AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception)),
    );
  }

  Future<void> _openResetPassword(UserAccount user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ResetPasswordDialog(user: user),
    );
  }

  Future<void> _openCreateUser() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        // Tag explicite : voir la même note dans admin_dashboard_screen.dart
        // ("Tournées") — les deux FAB sont montés en même temps par
        // IndexedStack.
        heroTag: 'admin-utilisateurs-fab',
        onPressed: _openCreateUser,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Créer un compte'),
      ),
      body: FutureBuilder<List<UserAccount>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les comptes.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingLg,
              AppDimensions.spacingSm,
              AppDimensions.spacingLg,
              AppDimensions.spacingXl * 2,
            ),
            children: [
              const Text('Utilisateurs', style: AppTypography.screenTitle),
              const SizedBox(height: AppDimensions.spacingLg),
              if (users.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.spacingXl),
                  child: Center(child: Text('Aucun compte pour le moment.')),
                )
              else
                for (final user in users) ...[
                  _UserCard(
                    user: user,
                    onToggleActive: () => _toggleActive(user),
                    onResetPassword: () => _openResetPassword(user),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  final UserAccount user;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Row(
          children: [
            Icon(
              user.actif ? Icons.check_circle : Icons.block,
              color: user.actif ? AppColors.success : AppColors.neutral,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nomAffichage,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.identifiant} · ${_roleLabel(user.role)}',
                    style: AppTypography.secondaryLabel,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle') onToggleActive();
                if (value == 'reset') onResetPassword();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(user.actif ? 'Désactiver' : 'Réactiver'),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Text('Réinitialiser le mot de passe'),
                ),
              ],
            ),
          ],
        ),
      ),
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
