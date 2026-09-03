import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';

/// Écran de connexion (Processus 1).
///
/// Remplace `login_placeholder_screen.dart` du Module 1. Volontairement
/// simple : un champ identifiant, un champ mot de passe, un seul bouton
/// d'action — conforme à la règle "maximum 3 actions principales par
/// écran" (PRD, chapitre 7) et à l'écran 4.1 du Cahier des charges.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifiantController = TextEditingController();
  final _motDePasseController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifiantController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifiant = _identifiantController.text.trim();
    final motDePasse = _motDePasseController.text;

    if (identifiant.isEmpty || motDePasse.isEmpty) {
      AppSnackbar.showError(context, 'Veuillez renseigner ces deux champs.');
      return;
    }

    setState(() => _isSubmitting = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.login(
      identifiant: identifiant,
      motDePasse: motDePasse,
    );

    if (!mounted) return;

    await result.when(
      success: (session) async {
        await ref.read(sessionProvider.notifier).open(session);
        // La redirection vers l'accueil du rôle est gérée automatiquement
        // par `app_router.dart` (redirect), pas ici.
      },
      failure: (exception) async {
        AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception));
      },
    );

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showForgotPasswordHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: const Text(
          'Aucune réinitialisation automatique n\'est disponible. '
          'Contactez votre administrateur : il peut réinitialiser '
          'votre mot de passe depuis la Gestion des comptes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'GENESIS PICKING',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                TextField(
                  controller: _identifiantController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                TextField(
                  controller: _motDePasseController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                PrimaryButton(
                  label: 'Se connecter',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                TextButton(
                  onPressed: _showForgotPasswordHelp,
                  child: const Text('Mot de passe oublié ?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
