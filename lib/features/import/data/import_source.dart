import 'dart:typed_data';

/// Contenu brut à importer, indépendant de sa provenance (sélection de
/// fichier, réception API future...).
///
/// Un seul type pour tous les formats : chaque [ImportParser] décide
/// lui-même comment interpréter [bytes] selon son format.
class ImportSource {
  const ImportSource({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}
