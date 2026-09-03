import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/media/product_image.dart';
import 'package:genesis_picking/core/widgets/media/zoomable_product_image.dart';

/// Vignette produit carrée, zoomable au toucher — un seul widget partagé
/// entre la ligne de picking du préparateur et la ligne de mission du
/// coursier, pour qu'elles affichent EXACTEMENT la même image, avec le
/// même comportement de zoom, jamais deux rendus légèrement différents.
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
        child: SizedBox(
          width: taille,
          height: taille,
          child: imageUrl == null
              ? Container(
                  color: AppColors.background,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 22,
                    color: AppColors.neutral,
                  ),
                )
              : ProductImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.background),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.background,
                    child: const Icon(
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
