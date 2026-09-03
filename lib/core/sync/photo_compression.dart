import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compression de photo partagée par tous les points de synchronisation
/// (`FirestoreTourRemoteSink`, `FirestoreCourierRequestRemoteSink`) : les
/// documents Firestore sont limités à 1 Mo et aucun forfait payant
/// (Firebase Storage) n'est disponible (carte prépayée refusée par Google
/// pour le forfait "Blaze" — décision du 29/08/2026), donc chaque photo
/// envoyée au serveur central est réduite avant écriture. La photo
/// ORIGINALE, en pleine résolution, n'est jamais touchée localement —
/// seule cette copie distante, destinée aux AUTRES appareils, est réduite
/// (principe "donnée d'origine jamais modifiée", voir CLAUDE.md).
class PhotoCompression {
  PhotoCompression._();

  /// Plus grande dimension (largeur ou hauteur) de la copie compressée —
  /// largement suffisant pour reconnaître un produit sur un écran de
  /// téléphone, tout en gardant chaque document très en dessous de la
  /// limite Firestore de 1 Mo (quelques dizaines de Ko en pratique).
  static const tailleMax = 480;
  static const qualiteJpeg = 70;

  /// Renvoie une version compressée de [imageUrl] (redimensionnée + JPEG
  /// qualité réduite), encodée en `data:` — jamais l'original. `null` si
  /// [imageUrl] est absente, déjà une vraie URL réseau (rien à
  /// compresser), ou si le décodage échoue.
  static String? compresser(String? imageUrl) {
    if (imageUrl == null || !imageUrl.startsWith('data:')) {
      return imageUrl;
    }
    final bytes = _decodeDataUri(imageUrl);
    if (bytes == null) return null;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final redimensionnee = decoded.width > decoded.height
        ? img.copyResize(decoded, width: tailleMax)
        : img.copyResize(decoded, height: tailleMax);

    final compressee = img.encodeJpg(redimensionnee, quality: qualiteJpeg);
    return 'data:image/jpeg;base64,${base64Encode(compressee)}';
  }

  static Uint8List? _decodeDataUri(String uri) {
    final commaIndex = uri.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(uri.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}
