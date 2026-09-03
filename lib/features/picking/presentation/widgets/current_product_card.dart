import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/media/product_image.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/progress_bar.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';

/// Carte plein écran du produit courant — LE composant central de l'écran
/// de picking (Refonte UI).
///
/// Affiche un seul produit à la fois (emplacement, quantité, photo, nom,
/// description, progression de la tournée) avec deux actions géantes en
/// bas, pour un usage à une main : jamais de liste, jamais de défilement
/// pour trouver l'information ou l'action.
class CurrentProductCard extends StatelessWidget {
  const CurrentProductCard({
    required this.produit,
    required this.progression,
    required this.onRecupere,
    required this.onIntrouvable,
    this.isSubmitting = false,
    super.key,
  });

  final PickingProduct produit;
  final PickingProgress progression;
  final VoidCallback onRecupere;
  final VoidCallback onIntrouvable;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressBar(progression: progression),
        const SizedBox(height: AppDimensions.spacingMd),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        label: 'EMPLACEMENT',
                        value: produit.emplacement,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    _InfoChip(
                      label: 'QUANTITÉ',
                      value: '× ${produit.quantiteDemandee}',
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _ProductPhoto(imageUrl: produit.imageUrl),
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  produit.nom,
                  style: AppTypography.productName,
                  textAlign: TextAlign.center,
                ),
                if (produit.description != null &&
                    produit.description!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    produit.description!,
                    style: AppTypography.secondaryLabel,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'INTROUVABLE',
                icon: Icons.warning_amber_rounded,
                background: const Color(0xFFFDECEB),
                foreground: AppColors.error,
                onPressed: isSubmitting ? null : onIntrouvable,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              flex: 2,
              child: _ActionButton(
                label: 'RÉCUPÉRÉ',
                icon: Icons.check_circle,
                background: AppColors.success,
                foreground: Colors.white,
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : onRecupere,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.chipLabel.copyWith(color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
        child: imageUrl == null
            ? const _PhotoFallback()
            : ProductImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.surfaceAlt),
                errorWidget: (_, __, ___) => const _PhotoFallback(),
              ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 48,
          color: AppColors.neutral,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.primaryButtonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusLg),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.buttonLabel.copyWith(color: foreground),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
