import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/courier/presentation/widgets/courier_quick_picker_sheet.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/presentation/picking_controller.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/picking_product_row.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/progress_bar.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/tour_complete_view.dart';

/// Écran de picking — LE moteur de GENESIS PICKING.
///
/// Liste complète des produits de la tournée, même disposition que la
/// picking list papier/PDF déjà utilisée sur le terrain (photo, quantité,
/// emplacement, produit) — plus rapide à parcourir d'un coup d'œil et
/// plus familier pour le préparateur qu'un produit isolé à la fois.
/// Validation directe sur chaque ligne. Aucune requête réseau : tout
/// provient de la session déjà chargée localement par [PickingController].
class PickingScreen extends ConsumerWidget {
  const PickingScreen({required this.tourId, super.key});

  final String tourId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSession = ref.watch(pickingControllerProvider(tourId));

    return Scaffold(
      appBar: AppBar(title: const Text('Picking')),
      body: asyncSession.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Text(
              error is AppException
                  ? ErrorHandler.userMessageFor(error)
                  : 'Une erreur est survenue.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (session) {
          if (session.estTerminee) {
            return TourCompleteView(tourId: tourId, session: session);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  0,
                ),
                child: ProgressBar(progression: session.progression),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMd,
                  ),
                  itemCount: session.produits.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final produit = session.produits[index];
                    return PickingProductRow(
                      produit: produit,
                      onValider: () => _valider(context, ref, produit),
                      onIntrouvable: () => _introuvable(ref, produit),
                      onEnvoyerCoursier: () =>
                          _envoyerCoursier(context, ref, produit),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _valider(
    BuildContext context,
    WidgetRef ref,
    PickingProduct produit,
  ) async {
    final controller = ref.read(pickingControllerProvider(tourId).notifier);
    await controller.validerProduit(
      produit.id,
      quantiteCollectee: produit.quantiteDemandee,
    );
    _reportErrorIfAny(context, ref);
  }

  /// 3ᵉ action de la ligne (🚚) : envoi direct à un coursier, produit
  /// entièrement introuvable (pas de qualification de quantité partielle
  /// — pour ça, [_introuvable] reste le chemin normal).
  Future<void> _envoyerCoursier(
    BuildContext context,
    WidgetRef ref,
    PickingProduct produit,
  ) async {
    final session = ref.read(sessionProvider);
    if (session == null) return; // défensif : le guard de navigation gère la session.

    final envoye = await showCourierQuickPickerSheet(
      context,
      preparateurId: session.userId,
      tourId: tourId,
      productLineId: produit.id,
      quantiteDemandee: produit.quantiteDemandee,
      emplacement: produit.emplacement,
    );

    if (envoye != true || !context.mounted) return;

    await ref
        .read(pickingControllerProvider(tourId).notifier)
        .marquerEnvoyeAuCoursier(produit.id);
  }

  /// Bouton ✕ de la ligne : un simple constat "pas encore trouvé", sans
  /// suite automatique — envoyer le produit à un coursier reste une action
  /// séparée et volontaire, voir le bouton 🚚 ([_envoyerCoursier]).
  Future<void> _introuvable(WidgetRef ref, PickingProduct produit) async {
    await ref
        .read(pickingControllerProvider(tourId).notifier)
        .marquerIntrouvable(produit.id);
  }

  void _reportErrorIfAny(BuildContext context, WidgetRef ref) {
    final state = ref.read(pickingControllerProvider(tourId));
    if (state.hasError) {
      final error = state.error;
      AppSnackbar.showError(
        context,
        error is AppException
            ? ErrorHandler.userMessageFor(error)
            : 'Une erreur est survenue.',
      );
    }
  }
}
