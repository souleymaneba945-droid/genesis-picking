import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';

/// Réinitialisation du mot de passe d'un compte (Cahier des charges,
/// écran 4.14). Volontairement une simple boîte de dialogue plutôt qu'un
/// écran complet : une seule information à saisir.
class ResetPasswordDialog extends ConsumerStatefulWidget {
  const ResetPasswordDialog({required this.user, super.key});

  final UserAccount user;

  @override
  ConsumerState<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nouveauMotDePasse = _controller.text;
    if (nouveauMotDePasse.length < 8) {
      AppSnackbar.showError(
        context,
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repository = ref.read(userRepositoryProvider);
    final result = await repository.resetPassword(
      userId: widget.user.id,
      nouveauMotDePasse: nouveauMotDePasse,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Mot de passe réinitialisé.');
        Navigator.of(context).pop();
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
      title: Text('Réinitialiser — ${widget.user.nomAffichage}'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Nouveau mot de passe',
          border: OutlineInputBorder(),
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
