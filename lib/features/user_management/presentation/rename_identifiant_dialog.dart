import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';

/// Renommage de l'identifiant de connexion d'un compte (Module 5 v2,
/// Rubrique 3) — même schéma que `ResetPasswordDialog` : une boîte de
/// dialogue plutôt qu'un écran complet, une seule information à saisir.
class RenameIdentifiantDialog extends ConsumerStatefulWidget {
  const RenameIdentifiantDialog({required this.user, super.key});

  final UserAccount user;

  @override
  ConsumerState<RenameIdentifiantDialog> createState() =>
      _RenameIdentifiantDialogState();
}

class _RenameIdentifiantDialogState
    extends ConsumerState<RenameIdentifiantDialog> {
  late final _controller = TextEditingController(text: widget.user.identifiant);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nouvelIdentifiant = _controller.text.trim();
    if (nouvelIdentifiant.isEmpty) {
      AppSnackbar.showError(context, 'L\'identifiant ne peut pas être vide.');
      return;
    }

    setState(() => _isSubmitting = true);

    final repository = ref.read(userRepositoryProvider);
    final result = await repository.renameIdentifiant(
      userId: widget.user.id,
      nouvelIdentifiant: nouvelIdentifiant,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Identifiant modifié.');
        Navigator.of(context).pop(true);
      },
      failure: (exception) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Renommer — ${widget.user.nomAffichage}'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Nouvel identifiant de connexion',
        ),
      ),
      actionsPadding: const EdgeInsets.all(AppDimensions.spacingMd),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
