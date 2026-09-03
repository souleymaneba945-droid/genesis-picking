import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;

/// Position d'une ligne de texte sur une page — nécessaire pour associer
/// une photo produit à la bonne ligne (voir `pdf_photo_extractor.dart`).
/// Coordonnées en points PDF (72 points = 1 pouce), origine en haut à
/// gauche de la page — mêmes unités que [syncfusion.PdfPage.size].
class PdfTextLinePosition {
  const PdfTextLinePosition({
    required this.pageIndex,
    required this.text,
    required this.top,
    required this.left,
  });

  final int pageIndex;
  final String text;
  final double top;
  final double left;
}

/// Extraction du texte brut ou positionné d'un PDF — séparée du parsing
/// métier ([PdfParser]) pour que la bibliothèque PDF concrète reste
/// isolée dans un seul fichier, remplaçable sans toucher à la logique
/// d'extraction des produits.
abstract interface class PdfTextExtractor {
  Future<String> extractText(Uint8List bytes);

  /// Position (page, haut, gauche) de chaque ligne de texte, dans l'ordre
  /// de lecture de chaque page — utilisé pour délimiter la zone de la
  /// photo de chaque produit (voir `PdfPhotoExtractor`), jamais pour le
  /// parsing du texte lui-même.
  Future<List<PdfTextLinePosition>> extractTextLinePositions(Uint8List bytes);
}

/// Implémentation basée sur `syncfusion_flutter_pdf` (licence
/// communautaire gratuite pour les petites structures — voir
/// MODULE_IMPORT.md, section dépendances, pour les conditions exactes).
class SyncfusionPdfTextExtractor implements PdfTextExtractor {
  @override
  Future<String> extractText(Uint8List bytes) async {
    final document = syncfusion.PdfDocument(inputBytes: bytes);
    try {
      return syncfusion.PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  @override
  Future<List<PdfTextLinePosition>> extractTextLinePositions(
    Uint8List bytes,
  ) async {
    final document = syncfusion.PdfDocument(inputBytes: bytes);
    try {
      final positions = <PdfTextLinePosition>[];
      for (var pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
        final lines = syncfusion.PdfTextExtractor(document).extractTextLines(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );
        for (final line in lines) {
          positions.add(
            PdfTextLinePosition(
              pageIndex: pageIndex,
              text: line.text,
              top: line.bounds.top,
              left: line.bounds.left,
            ),
          );
        }
      }
      return positions;
    } finally {
      document.dispose();
    }
  }
}
