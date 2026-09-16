import 'package:flutter/material.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/media/product_thumbnail.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// Une ligne de la liste de picking : image (badge quantité en coin),
/// numéro d'ordre + référence, produit, emplacement, et les actions
/// propres à son état — même disposition que la picking list papier/PDF
/// déjà utilisée sur le terrain, pour rester familière tout en ajoutant
/// la validation numérique.
///
/// Modernisation visuelle (13/09/2026, maquette v0.dev fournie par
/// l'utilisateur) : fond teinté selon l'état (vert = validé, rouge =
/// introuvable, ambre = envoyé au coursier), badge quantité directement
/// sur la vignette au lieu d'une colonne séparée, actions en boutons ronds
/// horizontaux plutôt qu'empilés verticalement — l'agrandissement de la
/// vignette du 03/09/2026 (retour terrain) reste respecté : la vignette
/// garde une taille confortable, seule la disposition des boutons change.
class PickingProductRow extends StatelessWidget {
  const PickingProductRow({
    required this.produit,
    required this.onValider,
    required this.onIntrouvable,
    required this.onEnvoyerCoursier,
    required this.onAnnuler,
    super.key,
  });

  final PickingProduct produit;
  final VoidCallback onValider;
  final VoidCallback onIntrouvable;

  /// 3ᵉ action de la ligne (🚚, bleu) : envoi direct à un coursier — action
  /// séparée et volontaire, indépendante de [onIntrouvable] (qui ne fait
  /// plus que constater "pas encore trouvé", sans déclencher d'envoi).
  final VoidCallback onEnvoyerCoursier;

  /// Annule une validation faite par erreur ("Annuler"/"Réessayer" selon
  /// l'état, retour terrain 13/09/2026) — remet la ligne à "à récupérer".
  /// Toujours fourni par l'appelant, mais jamais affiché par
  /// [_TrailingAction] pour [ProductState.envoyeAuCoursier] : une demande
  /// coursier existe déjà à ce stade, l'annuler ici ne l'annulerait pas
  /// côté coursier (voir `PickingController.annulerValidation`).
  final void Function(String productLineId) onAnnuler;

  (Color, BoxBorder?) get _apparenceFond => switch (produit.etat) {
        ProductState.collecte ||
        ProductState.partiellementCollecte =>
          (AppColors.successSoft, null),
        ProductState.introuvable => (AppColors.errorSoft, null),
        ProductState.envoyeAuCoursier => (AppColors.warningSoft, null),
        ProductState.aRecuperer => (
            AppColors.surface,
            Border.all(color: AppColors.divider),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (fond, bordure) = _apparenceFond;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingSm),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
        border: bordure,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ThumbnailWithBadge(imageUrl: produit.imageUrl, quantite: produit.quantiteDemandee),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(child: _ProductInfo(produit: produit)),
          const SizedBox(width: AppDimensions.spacingSm),
          _TrailingAction(
            produit: produit,
            onValider: onValider,
            onIntrouvable: onIntrouvable,
            onEnvoyerCoursier: onEnvoyerCoursier,
            onAnnuler: () => onAnnuler(produit.id),
          ),
        ],
      ),
    );
  }
}

/// Vignette produit avec la quantité demandée en badge sur le coin —
/// remplace l'ancienne colonne "×N" séparée, pour libérer de la largeur
/// pour le nom/l'emplacement (maquette v0.dev, 13/09/2026).
class _ThumbnailWithBadge extends StatelessWidget {
  const _ThumbnailWithBadge({required this.imageUrl, required this.quantite});

  final String? imageUrl;
  final int quantite;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ProductThumbnail(imageUrl: imageUrl, taille: 64),
        Positioned(
          top: -6,
          left: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: Text(
              '×$quantite',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Numéro d'ordre + référence, nom (barré une fois validé), emplacement —
/// tout ce qui identifie le produit et où le trouver, jamais tronqué au
/// point de devenir inutile (Refonte UI historique).
class _ProductInfo extends StatelessWidget {
  const _ProductInfo({required this.produit});

  final PickingProduct produit;

  bool get _valide =>
      produit.etat == ProductState.collecte ||
      produit.etat == ProductState.partiellementCollecte;

  @override
  Widget build(BuildContext context) {
    final description = produit.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          description != null && description.isNotEmpty
              ? '#${produit.ordre} · $description'
              : '#${produit.ordre}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.neutral,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          produit.nom,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: _valide ? TextDecoration.lineThrough : null,
            color: _valide ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                produit.emplacement,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Action de droite — dépend entièrement de l'état du produit : les 3
/// boutons ronds tant qu'il reste à faire, "Annuler"/"Réessayer" une fois
/// traité (sauf envoyé au coursier, qui n'a qu'un simple badge).
class _TrailingAction extends StatelessWidget {
  const _TrailingAction({
    required this.produit,
    required this.onValider,
    required this.onIntrouvable,
    required this.onEnvoyerCoursier,
    required this.onAnnuler,
  });

  final PickingProduct produit;
  final VoidCallback onValider;
  final VoidCallback onIntrouvable;
  final VoidCallback onEnvoyerCoursier;
  final VoidCallback onAnnuler;

  @override
  Widget build(BuildContext context) {
    return switch (produit.etat) {
      ProductState.aRecuperer => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundButton(
              icon: Icons.local_shipping_outlined,
              color: Colors.white,
              background: AppColors.primary,
              onPressed: onEnvoyerCoursier,
            ),
            const SizedBox(width: 6),
            _RoundButton(
              icon: Icons.close,
              color: AppColors.error,
              background: AppColors.errorSoft,
              onPressed: onIntrouvable,
            ),
            const SizedBox(width: 6),
            _RoundButton(
              icon: Icons.check,
              color: Colors.white,
              background: AppColors.success,
              onPressed: onValider,
            ),
          ],
        ),
      ProductState.collecte ||
      ProductState.partiellementCollecte =>
        _TextActionButton(
          icon: Icons.replay,
          label: 'Annuler',
          color: AppColors.success,
          onPressed: onAnnuler,
        ),
      ProductState.introuvable => _TextActionButton(
          icon: Icons.replay,
          label: 'Réessayer',
          color: AppColors.error,
          onPressed: onAnnuler,
        ),
      ProductState.envoyeAuCoursier => const StatusPill(
          label: 'Envoyé',
          background: AppColors.warningSoft,
          foreground: AppColors.warningText,
          icon: Icons.local_shipping_outlined,
        ),
    };
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(width: 36, height: 36, child: Icon(icon, color: color, size: 18)),
      ),
    );
  }
}

/// Bouton "Annuler"/"Réessayer" — remplace l'ancienne icône de statut
/// tapable par un vrai bouton étiqueté (retour terrain, 13/09/2026) :
/// plus visible, plus explicite que "juste une icône qu'on peut taper".
class _TextActionButton extends StatelessWidget {
  const _TextActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
