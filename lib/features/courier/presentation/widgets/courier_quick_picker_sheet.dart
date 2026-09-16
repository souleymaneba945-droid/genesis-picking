import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/media/product_thumbnail.dart';
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
///
/// [produitNom]/[produitImageUrl] sont purement d'affichage (carte résumé
/// du produit, Modernisation visuelle 12/09/2026, maquette v0.dev) — la
/// demande envoyée à `CourierService.createRequest` ne change pas.
Future<bool?> showCourierQuickPickerSheet(
  BuildContext context, {
  required String preparateurId,
  required String tourId,
  required String productLineId,
  required int quantiteDemandee,
  required String emplacement,
  required String produitNom,
  String? produitImageUrl,
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
      produitNom: produitNom,
      produitImageUrl: produitImageUrl,
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
    required this.produitNom,
    this.produitImageUrl,
  });

  final String preparateurId;
  final String tourId;
  final String productLineId;
  final int quantiteDemandee;
  final String emplacement;
  final String produitNom;
  final String? produitImageUrl;

  @override
  ConsumerState<_CourierQuickPickerSheet> createState() =>
      _CourierQuickPickerSheetState();
}

class _CourierQuickPickerSheetState
    extends ConsumerState<_CourierQuickPickerSheet> {
  late Future<List<CourierSummary>> _couriersFuture;
  bool _isSubmitting = false;

  /// Sélection en deux temps (Modernisation visuelle, 12/09/2026, à la
  /// lecture du prototype source `not-found-sheet.tsx`) : on choisit
  /// d'abord un coursier (mise en évidence, jamais d'envoi immédiat), puis
  /// on confirme via le bouton "Envoyer la demande" — évite qu'un tap
  /// isolé sur la mauvaise ligne envoie la demande par erreur.
  String? _selectedCourierId;

  @override
  void initState() {
    super.initState();
    _couriersFuture = ref.read(courierServiceProvider).listActiveCouriers();
  }

  Future<void> _envoyer(CourierSummary courier) async {
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
        margin: const EdgeInsets.only(
          left: AppDimensions.spacingMd,
          right: AppDimensions.spacingMd,
          bottom: AppDimensions.spacingMd,
        ),
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Produit introuvable',
                    style: AppTypography.screenTitle.copyWith(fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Text(
              'Envoyez un coursier vérifier en rayon, ou signalez-le simplement.',
              style: AppTypography.secondaryLabel,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
              ),
              child: Row(
                children: [
                  ProductThumbnail(imageUrl: widget.produitImageUrl, taille: 52),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.produitNom,
                          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '×${widget.quantiteDemandee} · ${widget.emplacement}',
                          style: AppTypography.secondaryLabel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            const Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: AppDimensions.spacingXs),
                Text('Assigner à un coursier', style: AppTypography.sectionTitle),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
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
                // Présélectionne le premier coursier (même défaut que le
                // prototype source) — évite d'exiger un tap "inutile"
                // quand un seul coursier est disponible.
                _selectedCourierId ??= couriers.first.id;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final courier in couriers) ...[
                      _CourierRow(
                        courier: courier,
                        selected: _selectedCourierId == courier.id,
                        enabled: !_isSubmitting,
                        onTap: () => setState(() => _selectedCourierId = courier.id),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            FutureBuilder<List<CourierSummary>>(
              future: _couriersFuture,
              builder: (context, snapshot) {
                final couriers = snapshot.data;
                if (couriers == null || couriers.isEmpty) {
                  return const SizedBox.shrink();
                }
                final selected = couriers.firstWhere(
                  (c) => c.id == _selectedCourierId,
                  orElse: () => couriers.first,
                );
                return PrimaryButton(
                  label: 'Envoyer la demande de vérification',
                  isLoading: _isSubmitting,
                  onPressed: () => _envoyer(selected),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne coursier sélectionnable (Modernisation visuelle, 12/09/2026,
/// alignée sur `not-found-sheet.tsx` du prototype source) — sélection en
/// deux temps : taper une ligne la met en évidence (bordure + fond teinté
/// `primary`, pastille radio cochée), mais n'envoie rien tant que le
/// bouton "Envoyer la demande" n'est pas pressé (voir
/// `_CourierQuickPickerSheetState._selectedCourierId`).
class _CourierRow extends StatelessWidget {
  const _CourierRow({
    required this.courier,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final CourierSummary courier;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  String get _initiales {
    final mots = courier.nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    return mots.take(2).map((m) => m[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.background,
      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primary,
                child: Text(_initiales, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(courier.nom, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      '${courier.demandesEnAttente} demande(s) en attente',
                      style: AppTypography.secondaryLabel,
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
