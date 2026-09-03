import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';

/// Création d'un compte utilisateur par l'Administrateur.
///
/// Trois informations strictement nécessaires (identifiant, nom
/// d'affichage, mot de passe initial) plus le choix du rôle — pas un
/// champ de plus, conformément au principe "zéro surcharge" (Directive
/// Architecture fonctionnelle, chapitre 1).
class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _identifiantController = TextEditingController();
  final _nomController = TextEditingController();
  final _motDePasseController = TextEditingController();
  UserRole _role = UserRole.preparateur;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _identifiantController.dispose();
    _nomController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifiant = _identifiantController.text.trim();
    final nom = _nomController.text.trim();
    final motDePasse = _motDePasseController.text;

    if (identifiant.isEmpty || nom.isEmpty || motDePasse.isEmpty) {
      AppSnackbar.showError(context, 'Veuillez renseigner tous les champs.');
      return;
    }
    if (motDePasse.length < 8) {
      AppSnackbar.showError(
        context,
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repository = ref.read(userRepositoryProvider);
    final result = await repository.create(
      identifiant: identifiant,
      nomAffichage: nom,
      role: _role,
      motDePasse: motDePasse,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Compte créé.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: 'Nom affiché',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: _identifiantController,
              decoration: const InputDecoration(
                labelText: 'Identifiant de connexion',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: _motDePasseController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe initial',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            DropdownButtonFormField<UserRole>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Rôle',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: UserRole.preparateur,
                  child: Text('Préparateur'),
                ),
                DropdownMenuItem(
                  value: UserRole.coursier,
                  child: Text('Coursier'),
                ),
                DropdownMenuItem(
                  value: UserRole.administrateur,
                  child: Text('Administrateur'),
                ),
              ],
              onChanged: (value) => setState(() => _role = value!),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            PrimaryButton(
              label: 'Créer le compte',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
