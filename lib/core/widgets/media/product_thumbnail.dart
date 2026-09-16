import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/media/product_image.dart';
import 'package:genesis_picking/core/widgets/media/zoomable_product_image.dart';

/// Vignette produit carrée, zoomable au toucher — un seul widget partagé
/// entre la ligne de picking du préparateur et la ligne de mission du
/// coursier, pour qu'elles affichent EXACTEMENT la même image, avec le
/// même comportement de zoom, jamais deux rendus légèrement différents.
///
/// `BoxFit.contain`, jamais `.cover` (corrigé 13/09/2026, retour visuel
/// direct sur le premier lancement Windows) : `.cover` remplit tout le
/// carré en ROGNANT l'image si son ratio ne correspond pas exactement —
/// avec des photos issues d'un scan PDF (formats hétérogènes), ça coupait
/// régulièrement un bord du produit. `.contain` montre TOUJOURS le
/// produit en entier, centré, quitte à laisser une petite marge sur les
/// côtés — d'où le fond [AppColors.surfaceAlt] derrière (même traitement
/// que la vue plein écran zoomée, déjà en `.contain` depuis le début, et
/// que le prototype source v0.dev : `bg-muted` + `object-contain`).
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({required this.imageUrl, super.key, this.taille = 60});

  final String? imageUrl;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.cornerRadius);
    return ZoomableProductImage(
      imageUrl: imageUrl,
      borderRadius: radius,
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          width: taille,
          height: taille,
          color: AppColors.surfaceAlt,
          child: imageUrl == null
              ? const Icon(
                  Icons.image_not_supported_outlined,
                  size: 22,
                  color: AppColors.neutral,
                )
              : Padding(
                  padding: EdgeInsets.all(taille * 0.08),
                  child: ProductImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      size: 22,
                      color: AppColors.neutral,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
