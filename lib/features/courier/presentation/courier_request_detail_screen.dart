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
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request_detail_view.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/warehouse_location/warehouse_location_providers.dart';

/// Écran de traitement d'une demande (Directive, "Traitement").
///
/// Affiche exactement ce qui est demandé : photo, nom, description/SKU,
/// quantité, emplacement, préparateur demandeur — identique à ce que le
/// préparateur voit sur sa liste de picking, jamais une présentation
/// appauvrie (le coursier s'appuie sur la photo et la description pour
/// retrouver le produit). Deux choix, et deux seulement : "Produit
/// retrouvé" / "Produit non retrouvé".
///
/// [requestIds] : une ou plusieurs demandes portant sur le MÊME produit
/// (Module 5 v2, Rubrique 1 — liste fusionnée, voir `CourierRequestsTab`)
/// — le produit n'est affiché qu'une fois, mais chaque préparateur
/// demandeur garde sa propre ligne (quantité/emplacement lui étant
/// propres, chacun sur sa propre tournée). Une seule action du coursier
/// (accepter en ouvrant l'écran, répondre) s'applique à TOUTES à la fois.
class CourierRequestDetailScreen extends ConsumerStatefulWidget {
  const CourierRequestDetailScreen({required this.requestIds, super.key});

  final List<String> requestIds;

  @override
  ConsumerState<CourierRequestDetailScreen> createState() =>
      _CourierRequestDetailScreenState();
}

class _CourierRequestDetailScreenState
    extends ConsumerState<CourierRequestDetailScreen> {
  late Future<
      ({List<CourierRequestDetailView> vues, String? emplacementEntrepot})?>
      _detailFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _open();
  }

  Future<({List<CourierRequestDetailView> vues, String? emplacementEntrepot})?>
      _open() async {
    final result = await ref
        .read(courierServiceProvider)
        .openGroup(widget.requestIds);
    return result.when(
      success: (vues) async {
        // Module 5 v2, Rubrique 2 : emplacement ENTREPÔT (par marque,
        // saisi par l'administrateur) — strictement séparé de l'emplacement
        // picking déjà affiché par préparateur ci-dessous, jamais mélangé.
        final emplacementEntrepot = await ref
            .read(warehouseLocationServiceProvider)
            .findEmplacement(vues.first.produitNom);
        return (vues: vues, emplacementEntrepot: emplacementEntrepot);
      },
      failure: (_) async => null,
    );
  }

  Future<void> _confirmerSuppression() async {
    final plusieurs = widget.requestIds.length > 1;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette demande ?'),
        content: Text(
          plusieurs
              ? 'Cette demande sera définitivement supprimée, sur cet '
                  'appareil et sur celui de chaque préparateur concerné. '
                  'Cette action est irréversible.'
              : 'Cette demande sera définitivement supprimée, sur cet '
                  'appareil et sur celui du préparateur. Cette action est '
                  'irréversible.',
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
        .deleteGroup(widget.requestIds);
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

    final result = await ref.read(courierServiceProvider).respondToGroup(
          requestIds: widget.requestIds,
          resultat: resultat,
        );

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
      body: FutureBuilder<
          ({List<CourierRequestDetailView> vues, String? emplacementEntrepot})?>(
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
          final donnees = snapshot.data;
          if (donnees == null || donnees.vues.isEmpty) {
            return const Center(child: Text('Demande introuvable.'));
          }
          final vues = donnees.vues;
          final emplacementEntrepot = donnees.emplacementEntrepot;
          // Même produit pour toutes (voir la docstring de classe) —
          // photo/nom/description pris sur la première, jamais recopiés.
          final detail = vues.first;

          final dejaTraitee = vues.every(
            (v) =>
                v.request.etat == CourierRequestStatus.traitee ||
                v.request.etat == CourierRequestStatus.terminee,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.cardPadding),
                    child: Column(
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
                        const SizedBox(height: AppDimensions.spacingMd),
                        if (detail.produitDescription != null &&
                            detail.produitDescription!.isNotEmpty)
                          Text(
                            detail.produitDescription!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.neutral,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          detail.produitNom,
                          style: AppTypography.screenTitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        _StatusPillFor(dejaTraitee: dejaTraitee),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Une ligne par préparateur demandeur — quantité et
                        // emplacement (picking) lui sont propres, chacun sur
                        // sa propre tournée (jamais fusionnés entre eux).
                        for (final vue in vues) ...[
                          _DemandeurRow(vue: vue),
                          if (vue != vues.last) const Divider(height: AppDimensions.spacingLg),
                        ],
                        const Divider(height: AppDimensions.spacingLg),
                        // Emplacement ENTREPÔT (Module 5 v2, Rubrique 2) —
                        // par marque, un seul pour tout le groupe
                        // (contrairement à l'emplacement picking ci-dessus) :
                        // STRICTEMENT séparé, jamais mélangé visuellement.
                        Row(
                          children: [
                            const Icon(Icons.warehouse_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Expanded(
                              child: Text(
                                emplacementEntrepot != null
                                    ? 'Emplacement entrepôt : $emplacementEntrepot'
                                    : 'Emplacement entrepôt non renseigné',
                                style: emplacementEntrepot != null
                                    ? AppTypography.body.copyWith(fontWeight: FontWeight.w600)
                                    : AppTypography.secondaryLabel.copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                if (dejaTraitee)
                  const Center(
                    child: Text(
                      'Cette demande a déjà été traitée.',
                      style: AppTypography.secondaryLabel,
                      textAlign: TextAlign.center,
                    ),
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

/// Pilule de statut global du groupe — vert "Traitée" une fois toutes les
/// demandes closes, bleu "En cours de traitement" sinon (le coursier a
/// déjà ouvert l'écran à ce stade, voir `_open`/`openGroup`).
class _StatusPillFor extends StatelessWidget {
  const _StatusPillFor({required this.dejaTraitee});

  final bool dejaTraitee;

  @override
  Widget build(BuildContext context) {
    return dejaTraitee
        ? const StatusPill(
            label: 'Traitée',
            background: AppColors.successSoft,
            foreground: AppColors.success,
            icon: Icons.check_circle_outline,
          )
        : const StatusPill(
            label: 'En cours de traitement',
            background: AppColors.primarySoft,
            foreground: AppColors.primary,
            icon: Icons.hourglass_top_outlined,
          );
  }
}

/// Une ligne "demandeur" — nom du préparateur, quantité et emplacement de
/// PICKING (jamais l'emplacement entrepôt, affiché séparément juste en
/// dessous de toutes ces lignes).
class _DemandeurRow extends StatelessWidget {
  const _DemandeurRow({required this.vue});

  final CourierRequestDetailView vue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vue.preparateurNom, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              Text(
                '×${vue.request.quantiteDemandee} · ${vue.request.emplacement}',
                style: AppTypography.secondaryLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
