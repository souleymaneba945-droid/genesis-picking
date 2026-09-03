import 'package:flutter/material.dart';
import 'package:genesis_picking/core/widgets/media/product_image.dart';

/// Rend [child] (l'affichage "normal" d'une photo produit) et ouvre, au
/// toucher, une vue PLEIN ÉCRAN zoomable (pincer/glisser via
/// `InteractiveViewer`, jusqu'à ×6) — partagée entre tous les écrans qui
/// affichent une photo produit (liste de picking, détail d'une demande
/// coursier), pour ne jamais dupliquer cette logique.
///
/// Transition en vol (`Hero`) entre la vignette et la vue plein écran, et
/// présentation "en carte flottante" sur fond noir (ombre portée) pour une
/// sensation de profondeur — un vrai modèle 3D pivotable n'existe pas
/// (rien dans une photo scannée du PDF ne porte d'information de
/// profondeur à extraire), donc ce qui est réellement livrable ici est
/// cette présentation soignée, pas une rotation d'objet.
///
/// Sans effet si [imageUrl] est `null` : rien à agrandir.
class ZoomableProductImage extends StatelessWidget {
  const ZoomableProductImage({
    required this.imageUrl,
    required this.child,
    this.borderRadius,
    this.heroTag,
    super.key,
  });

  final String? imageUrl;
  final Widget child;
  final BorderRadius? borderRadius;

  /// Identifiant unique de la transition `Hero` — par défaut [imageUrl]
  /// lui-même, mais à fournir explicitement (ex. l'id du produit) si deux
  /// lignes pouvaient un jour partager la même image.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return child;
    final tag = heroTag ?? url;

    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: borderRadius != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _ouvrirEnGrand(context, url, tag),
          child: child,
        ),
      ),
    );
  }

  static void _ouvrirEnGrand(BuildContext context, String imageUrl, Object tag) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, __) => FadeTransition(
          opacity: animation,
          child: _FullScreenProductImage(imageUrl: imageUrl, heroTag: tag),
        ),
      ),
    );
  }
}

/// Vue plein écran — occupe tout l'écran (pas une petite boîte centrée),
/// fond noir, zoom au pincement.
class _FullScreenProductImage extends StatefulWidget {
  const _FullScreenProductImage({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final Object heroTag;

  @override
  State<_FullScreenProductImage> createState() =>
      _FullScreenProductImageState();
}

class _FullScreenProductImageState extends State<_FullScreenProductImage> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_controller.value != Matrix4.identity()) {
      _controller.value = Matrix4.identity();
      return;
    }
    final position = details.localPosition;
    _controller.value = Matrix4.identity()
      ..translate(-position.dx * 1.5, -position.dy * 1.5)
      ..scale(2.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: _onDoubleTapDown,
                onDoubleTap: () {},
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 6,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: _CarteFlottante(
                        child: ProductImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.close, color: Colors.white),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Présentation "en carte flottante" (coins arrondis, ombre portée) —
/// c'est ce qui donne la sensation de profondeur sur le fond noir, sans
/// prétendre à un rendu 3D que la source (photo scannée) ne permet pas.
class _CarteFlottante extends StatelessWidget {
  const _CarteFlottante({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}
