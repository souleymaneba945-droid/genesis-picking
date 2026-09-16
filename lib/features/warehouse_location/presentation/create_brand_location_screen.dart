import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/warehouse_location/warehouse_location_providers.dart';

/// Création d'une correspondance marque → emplacement entrepôt par
/// l'Administrateur (Module 5 v2, Rubrique 2) — même schéma que
/// `CreateUserScreen` : deux informations strictement nécessaires, pas un
/// champ de plus.
class CreateBrandLocationScreen extends ConsumerStatefulWidget {
  const CreateBrandLocationScreen({super.key});

  @override
  ConsumerState<CreateBrandLocationScreen> createState() =>
      _CreateBrandLocationScreenState();
}

class _CreateBrandLocationScreenState
    extends ConsumerState<CreateBrandLocationScreen> {
  final _marqueController = TextEditingController();
  final _emplacementController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _marqueController.dispose();
    _emplacementController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final marque = _marqueController.text.trim();
    final emplacement = _emplacementController.text.trim();

    if (marque.isEmpty || emplacement.isEmpty) {
      AppSnackbar.showError(context, 'Veuillez renseigner tous les champs.');
      return;
    }

    setState(() => _isSubmitting = true);

    final repository = ref.read(brandWarehouseLocationRepositoryProvider);
    final result = await repository.create(marque: marque, emplacement: emplacement);

    if (!mounted) return;

    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Emplacement créé.');
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
      appBar: AppBar(title: const Text('Nouvel emplacement')),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _marqueController,
              decoration: const InputDecoration(
                labelText: 'Marque',
                hintText: 'Ex. Mustela',
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: _emplacementController,
              decoration: const InputDecoration(
                labelText: 'Emplacement dans l\'entrepôt',
                hintText: 'Ex. Zone A - Étagère 3',
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            PrimaryButton(
              label: 'Créer l\'emplacement',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
