import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Remplacement direct de [CachedNetworkImage] (mêmes paramètres,
/// interchangeable partout où il était utilisé) qui sait aussi afficher
/// une image encodée en `data:` URI — le cas normal ici : les photos
/// extraites du PDF importé sont stockées directement en base ainsi (voir
/// `pdf_photo_extractor.dart`), pas comme une vraie URL réseau.
/// [CachedNetworkImage] ne sait faire une requête que sur une vraie URL
/// http(s) : sans ce détour, CHAQUE photo échouait silencieusement (repli
/// systématique sur `errorWidget`) — confirmé sur un vrai appareil avec
/// une vraie tournée importée (322 produits, aucune image affichée).
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.imageUrl,
    super.key,
    this.fit,
    this.height,
    this.width,
    this.placeholder,
    this.errorWidget,
    this.filterQuality = FilterQuality.high,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? height;
  final double? width;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  /// `FilterQuality.high` par défaut (au lieu du `.low` par défaut de
  /// Flutter) : une vignette redimensionnée depuis la photo source, en
  /// haute résolution (voir `pdf_photo_extractor.dart`, rendu à ~430 ppp),
  /// a l'air nettement plus nette avec un meilleur filtre de
  /// redimensionnement — coût CPU négligeable pour des images de cette
  /// taille (03/09/2026, retour terrain : "la netteté est à revoir").
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataUri(imageUrl);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        height: height,
        width: width,
        filterQuality: filterQuality,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget?.call(context, imageUrl, error) ??
            const SizedBox.shrink(),
      );
    }
    // Pas une data URI (payload corrompu, ou vraie URL réseau si la
    // synchronisation distante alimente un jour ce champ) : comportement
    // inchangé, requête réseau classique.
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      height: height,
      width: width,
      filterQuality: filterQuality,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// `null` si [uri] n'est pas une data URI valide.
  static Uint8List? _decodeDataUri(String uri) {
    if (!uri.startsWith('data:')) return null;
    final commaIndex = uri.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(uri.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}
