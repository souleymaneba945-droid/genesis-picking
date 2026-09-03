import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/media/product_thumbnail.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Une ligne de la liste de picking : image, quantité, emplacement,
/// produit, et deux boutons de validation — même disposition que la
/// picking list papier/PDF déjà utilisée sur le terrain, pour rester
/// familière tout en ajoutant la validation numérique. Vignette
/// suffisamment grande pour vraiment reconnaître le produit d'un coup
/// d'œil (Refonte UI — les photos sont maintenant réellement extraites
/// du PDF, pas de raison de les afficher minuscules).
class PickingProductRow extends StatelessWidget {
  const PickingProductRow({
    required this.produit,
    required this.onValider,
    required this.onIntrouvable,
    required this.onEnvoyerCoursier,
    super.key,
  });

  final PickingProduct produit;
  final VoidCallback onValider;
  final VoidCallback onIntrouvable;

  /// 3ᵉ action de la ligne (🚚, bleu) : envoi direct à un coursier — action
  /// séparée et volontaire, indépendante de [onIntrouvable] (qui ne fait
  /// plus que constater "pas encore trouvé", sans déclencher d'envoi).
  final VoidCallback onEnvoyerCoursier;

  bool get _estTraite => produit.etat != ProductState.aRecuperer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: _estTraite ? Colors.transparent : AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
      ),
      child: Opacity(
        opacity: _estTraite ? 0.5 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProductThumbnail(imageUrl: produit.imageUrl),
            const SizedBox(width: AppDimensions.spacingSm),
            SizedBox(
              width: 20,
              child: Text(
                '${produit.quantiteDemandee}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                produit.emplacement,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Expanded(
              // Même contenu que la cellule "Produit" de la picking list
              // PDF : la référence (SKU - code-barres) au-dessus du nom —
              // sans aucune troncature (ni maxLines ni ellipsis) : le
              // préparateur/coursier s'appuie sur ce texte en entier pour
              // identifier le produit, une référence coupée est inutile.
              // La ligne s'agrandit verticalement autant que nécessaire.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (produit.description != null &&
                      produit.description!.isNotEmpty)
                    Text(
                      produit.description!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.neutral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    produit.nom,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            _estTraite ? _StatusIcon(etat: produit.etat) : _ActionButtons(
              onValider: onValider,
              onIntrouvable: onIntrouvable,
              onEnvoyerCoursier: onEnvoyerCoursier,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onValider,
    required this.onIntrouvable,
    required this.onEnvoyerCoursier,
  });

  final VoidCallback onValider;
  final VoidCallback onIntrouvable;
  final VoidCallback onEnvoyerCoursier;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RowButton(
          icon: Icons.close,
          color: AppColors.error,
          background: const Color(0xFFFDECEB),
          onPressed: onIntrouvable,
          taille: 34,
        ),
        const SizedBox(width: 5),
        _RowButton(
          icon: Icons.local_shipping_outlined,
          color: Colors.white,
          background: AppColors.primary,
          onPressed: onEnvoyerCoursier,
          taille: 34,
        ),
        const SizedBox(width: 5),
        _RowButton(
          icon: Icons.check,
          color: Colors.white,
          background: AppColors.success,
          onPressed: onValider,
          taille: 34,
        ),
      ],
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onPressed,
    this.taille = 40,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onPressed;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: SizedBox(
          width: taille,
          height: taille,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.etat});

  final ProductState etat;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (etat) {
      ProductState.collecte => (Icons.check_circle, AppColors.success),
      ProductState.partiellementCollecte => (
          Icons.check_circle_outline,
          AppColors.warning,
        ),
      ProductState.introuvable => (Icons.close, AppColors.error),
      ProductState.envoyeAuCoursier => (
          Icons.local_shipping_outlined,
          AppColors.warning,
        ),
      ProductState.aRecuperer => (Icons.circle_outlined, AppColors.neutral),
    };
    return SizedBox(
      width: 40,
      height: 40,
      child: Icon(icon, color: color),
    );
  }
}
