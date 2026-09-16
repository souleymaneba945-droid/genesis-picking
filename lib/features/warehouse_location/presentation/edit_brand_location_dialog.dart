import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/warehouse_location_providers.dart';

/// Modification d'une correspondance marque → emplacement existante
/// (Module 5 v2, Rubrique 2) — même schéma que `ResetPasswordDialog` :
/// une boîte de dialogue plutôt qu'un écran complet.
class EditBrandLocationDialog extends ConsumerStatefulWidget {
  const EditBrandLocationDialog({required this.location, super.key});

  final BrandWarehouseLocation location;

  @override
  ConsumerState<EditBrandLocationDialog> createState() =>
      _EditBrandLocationDialogState();
}

class _EditBrandLocationDialogState
    extends ConsumerState<EditBrandLocationDialog> {
  late final _marqueController = TextEditingController(text: widget.location.marque);
  late final _emplacementController =
      TextEditingController(text: widget.location.emplacement);
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
    final result = await repository.update(
      id: widget.location.id,
      marque: marque,
      emplacement: emplacement,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Emplacement modifié.');
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
      title: const Text('Modifier l\'emplacement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _marqueController,
            decoration: const InputDecoration(
              labelText: 'Marque',
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          TextField(
            controller: _emplacementController,
            decoration: const InputDecoration(
              labelText: 'Emplacement dans l\'entrepôt',
            ),
          ),
        ],
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
