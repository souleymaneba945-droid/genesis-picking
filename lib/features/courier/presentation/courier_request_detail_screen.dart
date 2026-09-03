import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/media/product_image.dart';
import 'package:genesis_picking/core/widgets/media/zoomable_product_image.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request_detail_view.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Écran de traitement d'une demande (Directive, "Traitement").
///
/// Affiche exactement ce qui est demandé : photo, nom, description/SKU,
/// quantité, emplacement, préparateur demandeur — identique à ce que le
/// préparateur voit sur sa liste de picking, jamais une présentation
/// appauvrie (le coursier s'appuie sur la photo et la description pour
/// retrouver le produit). Deux choix, et deux seulement : "Produit
/// retrouvé" / "Produit non retrouvé".
class CourierRequestDetailScreen extends ConsumerStatefulWidget {
  const CourierRequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<CourierRequestDetailScreen> createState() =>
      _CourierRequestDetailScreenState();
}

class _CourierRequestDetailScreenState
    extends ConsumerState<CourierRequestDetailScreen> {
  late Future<CourierRequestDetailView?> _detailFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _open();
  }

  Future<CourierRequestDetailView?> _open() async {
    final result = await ref
        .read(courierServiceProvider)
        .openRequest(widget.requestId);
    return result.when(success: (view) => view, failure: (_) => null);
  }

  Future<void> _confirmerSuppression() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette demande ?'),
        content: const Text(
          'Cette demande sera définitivement supprimée, sur cet appareil '
          'et sur celui du préparateur. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;

    final result = await ref
        .read(courierServiceProvider)
        .deleteRequest(widget.requestId);
    if (!mounted) return;
    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Demande supprimée.');
        Navigator.of(context).pop();
      },
      failure: (exception) =>
          AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception)),
    );
  }

  Future<void> _respond(CourierRequestResult resultat) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final result = await ref
        .read(courierServiceProvider)
        .respond(requestId: widget.requestId, resultat: resultat);

    if (!mounted) return;

    result.when(
      success: (_) => Navigator.of(context).pop(),
      failure: (exception) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demande'),
        actions: [
          IconButton(
            onPressed: _confirmerSuppression,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer la demande',
          ),
        ],
      ),
      body: FutureBuilder<CourierRequestDetailView?>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger cette demande.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Demande introuvable.'));
          }

          final dejaTraitee =
              detail.request.etat == CourierRequestStatus.traitee ||
              detail.request.etat == CourierRequestStatus.terminee;

          return Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detail.produitImageUrl != null)
                  ZoomableProductImage(
                    imageUrl: detail.produitImageUrl,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.cornerRadius,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.cornerRadius,
                      ),
                      child: ProductImage(
                        imageUrl: detail.produitImageUrl!,
                        height: 140,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const SizedBox(
                          height: 140,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const _ImagePlaceholder(),
                      ),
                    ),
                  )
                else
                  const _ImagePlaceholder(),
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  detail.produitNom,
                  style: AppTypography.screenTitle,
                  textAlign: TextAlign.center,
                ),
                if (detail.produitDescription != null &&
                    detail.produitDescription!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    detail.produitDescription!,
                    style: AppTypography.secondaryLabel,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppDimensions.spacingMd),
                Text(
                  'Quantité demandée : ${detail.request.quantiteDemandee}',
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Emplacement : ${detail.request.emplacement}',
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Demandé par : ${detail.preparateurNom}',
                  style: AppTypography.secondaryLabel,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (dejaTraitee)
                  const Text(
                    'Cette demande a déjà été traitée.',
                    textAlign: TextAlign.center,
                  )
                else ...[
                  PrimaryButton(
                    label: 'Produit retrouvé',
                    isLoading: _isSubmitting,
                    onPressed: () => _respond(CourierRequestResult.retrouve),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _respond(CourierRequestResult.nonRetrouve),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppDimensions.primaryButtonHeight,
                      ),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Produit non retrouvé'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
      ),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.neutral,
        size: 40,
      ),
    );
  }
}
