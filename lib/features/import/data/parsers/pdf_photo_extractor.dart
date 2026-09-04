import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart' as rx;

/// Zone rectangulaire d'une page à rendre en photo — en points PDF (même
/// origine haut-gauche que [PdfTextLinePosition]).
class PdfPhotoRegion {
  const PdfPhotoRegion({
    required this.pageIndex,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final int pageIndex;
  final double top;
  final double bottom;
  final double left;
  final double right;
}

/// Rend et encode la photo produit présente dans une zone d'une page PDF
/// — jamais générée ni devinée : c'est littéralement le rendu des pixels
/// réels de cette zone de la page source.
abstract interface class PdfPhotoExtractor {
  /// Une entrée par [regions], dans le même ordre. `null` à une position
  /// si le rendu échoue ou si la zone est vide (pas de photo pour cette
  /// ligne dans la source) — jamais une image inventée pour compenser.
  ///
  /// [onProgress], si fourni, est appelé après CHAQUE région rendue avec
  /// (nombre déjà rendu, total) — c'est le rendu page par page qui domine
  /// la durée d'un import volumineux (voir la docstring de [PdfParser]),
  /// donc la seule étape où une progression réelle a un sens à afficher.
  Future<List<Uint8List?>> extractPhotos(
    Uint8List bytes,
    List<PdfPhotoRegion> regions, {
    void Function(int done, int total)? onProgress,
  });
}

/// Implémentation `pdfrx` (moteur pdfium, multiplateforme y compris Web
/// en WASM) : `syncfusion_flutter_pdf` (utilisé pour le texte) n'expose
/// aucune extraction d'image, dans aucune version — confirmé sur le
/// changelog complet avant de choisir cette bibliothèque additionnelle.
class PdfrxPhotoExtractor implements PdfPhotoExtractor {
  /// Échelle de rendu — environ 430 ppp (72 ppp natif × 6) : bien plus
  /// qu'il n'en faut pour une vignette, mais nécessaire pour que le zoom
  /// (jusqu'à ×5, voir `ZoomableProductImage`) reste net plutôt que
  /// pixelisé une fois agrandi.
  static const double _scale = 6.0;

  /// Une zone rendue presque entièrement blanche = pas de photo pour
  /// cette ligne dans la source (ça arrive : voir la Directive Module
  /// Import, "emplacement parfois absent") — mieux vaut `null` qu'un
  /// JPEG blanc inutile stocké pour rien.
  static const double _seuilBlanc = 250;

  /// Écart-type maximal (sur 0-255) pour qu'une zone claire soit
  /// considérée uniforme (donc vide) plutôt que "photo sur fond blanc".
  static const double _seuilEcartType = 5;

  @override
  Future<List<Uint8List?>> extractPhotos(
    Uint8List bytes,
    List<PdfPhotoRegion> regions, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (regions.isEmpty) return const [];

    final document = await rx.PdfDocument.openData(bytes);
    try {
      final results = <Uint8List?>[];
      for (var i = 0; i < regions.length; i++) {
        results.add(await _renderRegion(document, regions[i]));
        onProgress?.call(i + 1, regions.length);
      }
      return results;
    } finally {
      document.dispose();
    }
  }

  Future<Uint8List?> _renderRegion(
    rx.PdfDocument document,
    PdfPhotoRegion region,
  ) async {
    if (region.pageIndex < 0 || region.pageIndex >= document.pages.length) {
      return null;
    }

    final page = document.pages[region.pageIndex];
    final fullWidth = page.width * _scale;
    final fullHeight = page.height * _scale;

    final xPx = (region.left * _scale).round().clamp(0, fullWidth.round());
    final yPx = (region.top * _scale).round().clamp(0, fullHeight.round());
    // La région demandée peut dépasser la page réelle (ex. dernière ligne
    // d'une page sans pied de page détecté pour la borner) : sans cette
    // limite, le rendu déborde en blanc au-delà du contenu réel de la
    // page — jamais une zone plus grande que la page elle-même.
    final wPx = ((region.right - region.left) * _scale)
        .round()
        .clamp(0, (fullWidth - xPx).round());
    final hPx = ((region.bottom - region.top) * _scale)
        .round()
        .clamp(0, (fullHeight - yPx).round());
    if (wPx <= 0 || hPx <= 0) return null;

    rx.PdfImage? rendered;
    try {
      rendered = await page.render(
        x: xPx,
        y: yPx,
        width: wPx,
        height: hPx,
        fullWidth: fullWidth,
        fullHeight: fullHeight,
      );
      if (rendered == null) return null;

      final decoded = img.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: rendered.pixels.buffer,
        order: img.ChannelOrder.bgra,
      );

      // La région passée par PdfParser (voir `_associerPhotos`) couvre
      // toute la largeur de la ligne jusqu'à la colonne quantité — bien
      // plus large que la photo elle-même pour un produit haut et étroit
      // (ex. un flacon), qui n'en occupe alors qu'une bande centrale.
      // Sans ce recadrage, le zoom plein écran (`ZoomableProductImage`)
      // affichait un produit minuscule au milieu d'un grand cadre blanc
      // plutôt qu'une photo qui remplit l'écran (retour terrain,
      // 04/09/2026). Recadre sur le contenu réel, PAS sur une zone
      // devinée : simple retrait des marges uniformément blanches
      // autour de ce qui a été rendu.
      final recadree = _recadrerSurContenu(decoded);

      if (_estPresqueBlanc(recadree)) return null;
      return Uint8List.fromList(img.encodeJpg(recadree, quality: 95));
    } catch (_) {
      // Une région illisible (rendu échoué) ne doit jamais faire
      // planter tout l'import : cette seule photo reste absente.
      return null;
    } finally {
      rendered?.dispose();
    }
  }

  /// Marge de sécurité (en pixels, à l'échelle [_scale]) laissée autour
  /// du contenu détecté — jamais 0 : raser exactement au pixel détecté
  /// risquerait de couper un bord de produit légèrement clair (reflet,
  /// anti-aliasing du rendu PDF) plutôt que de garder un peu de blanc.
  static const int _margeRecadrage = 6;

  /// Seuil de luminosité (0-255) sous lequel un pixel compte comme
  /// "contenu" plutôt que marge blanche — délibérément plus permissif
  /// que [_seuilBlanc] (qui détecte une case ENTIÈREMENT vide) : ici
  /// c'est l'inverse, on cherche à ne perdre AUCUN pixel qui appartient
  /// réellement au produit, y compris ses zones claires.
  static const double _seuilContenu = 248;

  /// Retire les marges uniformément blanches autour du contenu réel de
  /// [image] — jamais un recadrage deviné : la boîte englobante est
  /// calculée sur les pixels effectivement rendus, avec [_margeRecadrage]
  /// de marge de sécurité. Retourne [image] inchangée si aucun contenu
  /// n'est détecté (page vide — laissé à [_estPresqueBlanc] juste après)
  /// ou si la boîte calculée est dégénérée.
  img.Image _recadrerSurContenu(img.Image image) {
    const pas = 3;
    var minX = image.width;
    var maxX = -1;
    var minY = image.height;
    var maxY = -1;

    for (var y = 0; y < image.height; y += pas) {
      for (var x = 0; x < image.width; x += pas) {
        final pixel = image.getPixel(x, y);
        final luminosite = (pixel.r + pixel.g + pixel.b) / 3;
        if (luminosite < _seuilContenu) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < 0 || maxY < 0) return image;

    final left = (minX - _margeRecadrage).clamp(0, image.width);
    final top = (minY - _margeRecadrage).clamp(0, image.height);
    final right = (maxX + _margeRecadrage).clamp(0, image.width);
    final bottom = (maxY + _margeRecadrage).clamp(0, image.height);
    final largeur = right - left;
    final hauteur = bottom - top;
    if (largeur <= 0 || hauteur <= 0) return image;

    return img.copyCrop(image, x: left, y: top, width: largeur, height: hauteur);
  }

  bool _estPresqueBlanc(img.Image image) {
    // La seule moyenne de luminosité ne suffit pas : une vraie photo
    // produit sur fond blanc (très fréquent) peut dépasser un seuil de
    // moyenne à elle seule (vérifié sur ce fichier : plusieurs photos
    // réelles moyennaient >250/255) — ce serait alors une photo réelle
    // supprimée à tort. Une case VRAIMENT vide, elle, est non seulement
    // claire mais quasi UNIFORME (variance proche de zéro) : les deux
    // conditions ensemble distinguent correctement "silhouette de
    // produit sur fond blanc" de "rien du tout". En cas de doute, on
    // garde la photo plutôt que de la supprimer — mieux vaut une case
    // blanche honnête qu'une vraie photo perdue.
    var total = 0.0;
    final echantillons = <double>[];
    const pas = 5;
    for (var y = 0; y < image.height; y += pas) {
      for (var x = 0; x < image.width; x += pas) {
        final pixel = image.getPixel(x, y);
        final luminosite = (pixel.r + pixel.g + pixel.b) / 3;
        total += luminosite;
        echantillons.add(luminosite);
      }
    }
    if (echantillons.isEmpty) return true;

    final moyenne = total / echantillons.length;
    final variance =
        echantillons.map((v) => (v - moyenne) * (v - moyenne)).reduce((a, b) => a + b) /
        echantillons.length;
    final ecartType = sqrt(variance);

    return moyenne > _seuilBlanc && ecartType < _seuilEcartType;
  }
}
