import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_summary.dart';

/// Sélecteur rapide de coursier — ouvert depuis le 3ᵉ bouton (🚚, bleu) de
/// la ligne de picking, seule et unique façon d'envoyer un produit à un
/// coursier depuis l'écran de picking (le bouton ✕ ne fait plus que
/// constater "pas encore trouvé" — voir `PickingScreen._introuvable` — il
/// n'ouvre plus aucun écran de choix de coursier). Envoie toujours la
/// quantité demandée en totalité : aucune qualification de quantité
/// partiellement trouvée n'est proposée ici.
///
/// Renvoie `true` si une demande a bien été créée (l'appelant doit alors
/// marquer le produit "Envoyé au coursier"), `null` sinon (annulé/fermé).
Future<bool?> showCourierQuickPickerSheet(
  BuildContext context, {
  required String preparateurId,
  required String tourId,
  required String productLineId,
  required int quantiteDemandee,
  required String emplacement,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CourierQuickPickerSheet(
      preparateurId: preparateurId,
      tourId: tourId,
      productLineId: productLineId,
      quantiteDemandee: quantiteDemandee,
      emplacement: emplacement,
    ),
  );
}

class _CourierQuickPickerSheet extends ConsumerStatefulWidget {
  const _CourierQuickPickerSheet({
    required this.preparateurId,
    required this.tourId,
    required this.productLineId,
    required this.quantiteDemandee,
    required this.emplacement,
  });

  final String preparateurId;
  final String tourId;
  final String productLineId;
  final int quantiteDemandee;
  final String emplacement;

  @override
  ConsumerState<_CourierQuickPickerSheet> createState() =>
      _CourierQuickPickerSheetState();
}

class _CourierQuickPickerSheetState
    extends ConsumerState<_CourierQuickPickerSheet> {
  late Future<List<CourierSummary>> _couriersFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _couriersFuture = ref.read(courierServiceProvider).listActiveCouriers();
  }

  Future<void> _choisir(CourierSummary courier) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final result = await ref.read(courierServiceProvider).createRequest(
          preparateurId: widget.preparateurId,
          coursierId: courier.id,
          tourId: widget.tourId,
          productLineId: widget.productLineId,
          quantiteDemandee: widget.quantiteDemandee,
          emplacement: widget.emplacement,
        );

    if (!mounted) return;

    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (exception) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.spacingMd),
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Envoyer à un coursier',
              style: AppTypography.screenTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            FutureBuilder<List<CourierSummary>>(
              future: _couriersFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingMd,
                    ),
                    child: Text('Impossible de charger les coursiers.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingXl,
                    ),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final couriers = snapshot.data!;
                if (couriers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingMd,
                    ),
                    child: Text('Aucun coursier actif pour le moment.'),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final courier in couriers)
                      ListTile(
                        enabled: !_isSubmitting,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          foregroundColor: AppColors.primary,
                          child: Icon(Icons.local_shipping_outlined),
                        ),
                        title: Text(courier.nom),
                        subtitle: Text(
                          '${courier.demandesEnAttente} demande(s) en attente',
                        ),
                        onTap: () => _choisir(courier),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
