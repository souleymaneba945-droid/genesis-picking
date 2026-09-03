import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/sync/photo_compression.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';

/// Point d'entrée en écriture, côté import, vers le serveur central —
/// symétrique de [TourRemoteSource] (lecture). Appelé par `ImportEngine`
/// juste après un import réussi et déjà stocké localement (jamais avant :
/// la donnée locale reste systématiquement la première écrite, cette
/// transmission est additive et best-effort, voir [FirestoreTourRemoteSink]).
abstract interface class TourRemoteSink {
  Future<void> pushImportedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  });

  /// Supprime une tournée du serveur (métadonnées + toutes ses lignes
  /// produits) — appelée par [TourService.deleteTour] juste après la
  /// suppression locale. Indispensable, pas optionnelle : sans elle, le
  /// document Firestore de la tournée survivrait et réapparaîtrait comme
  /// "disponible" au prochain `refreshAvailableTours` sur n'importe quel
  /// appareil du même préparateur (voir `registerAvailableTour`, qui
  /// recrée une tournée absente localement).
  Future<void> deleteTour(String tourId);
}

/// Implémentation "sans destination" — symétrique de [NoTourRemoteSource],
/// utilisée tant que Firebase n'est pas disponible/configuré sur un
/// build donné (tests, ou environnement sans clés Firebase).
class NoTourRemoteSink implements TourRemoteSink {
  const NoTourRemoteSink();

  @override
  Future<void> pushImportedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  }) async {}

  @override
  Future<void> deleteTour(String tourId) async {}
}

/// Transmet une tournée fraîchement importée vers Firestore — métadonnées,
/// lignes produits, ET une version compressée de chaque photo, embarquée
/// directement dans le document (pas de Firebase Storage : décision du
/// 29/08/2026, carte prépayée refusée par Google pour activer le forfait
/// payant "Blaze" nécessaire à Storage). La photo ORIGINALE, en pleine
/// résolution, reste inchangée dans la base locale de l'appareil qui a
/// fait l'import — seule cette copie distante, destinée aux AUTRES
/// appareils, est réduite. Conforme au principe "donnée d'origine jamais
/// modifiée" : ce n'est jamais la même donnée qui est altérée, seulement
/// une seconde copie créée pour un usage différent (faire tenir la photo
/// dans la limite de 1 Mo par document Firestore, en restant gratuit).
///
/// Best-effort et non bloquant par conception : appelée APRÈS que
/// `TourRepository.saveDownloadedTour` a déjà écrit la tournée localement
/// (donnée jamais perdue même hors-ligne, conforme au principe Offline
/// First) — un échec réseau ici est journalisé, jamais renvoyé comme
/// échec de l'import lui-même (voir `ImportEngine.import`).
class FirestoreTourRemoteSink implements TourRemoteSink {
  FirestoreTourRemoteSink(this._firestore);

  final FirebaseFirestore _firestore;

  static const _toursCollection = 'tours';
  static const _productLinesCollection = 'tour_product_lines';

  /// Taille des lots traités successivement — une tournée peut compter
  /// jusqu'à environ 1000 produits (picking list volumineuse) : envoyer
  /// TOUTES les écritures (chacune avec sa photo) strictement en même
  /// temps saturerait la connexion et la mémoire de l'appareil, en
  /// particulier sur un téléphone d'entrée de gamme. Ce découpage garde
  /// un débit élevé (toujours plusieurs écritures en parallèle) sans
  /// jamais dépendre du nombre total de produits.
  static const _tailleLot = 25;

  @override
  Future<void> pushImportedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  }) async {
    await _firestore
        .collection(_toursCollection)
        .doc(tourId)
        .set({
          'numeroTournee': numeroTournee,
          'preparateurId': preparateurId,
          'nombreTotalProduits': produits.length,
          'pushedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 20));

    for (var i = 0; i < produits.length; i += _tailleLot) {
      final lot = produits.skip(i).take(_tailleLot).toList();

      // Compression de tout le lot en un seul aller dans un isolate à
      // part — jamais sur le fil principal (Flutter) : décoder,
      // redimensionner et ré-encoder chaque photo est un travail CPU qui
      // gèlerait l'écran pendant tout l'import s'il tournait ici. Un seul
      // isolate par LOT (pas un par photo) : ouvrir un isolate a lui-même
      // un coût, qu'il vaut mieux répartir sur tout un lot plutôt que le
      // payer une fois par produit sur une tournée de 1000 lignes.
      List<String?> imagesCompressees;
      try {
        imagesCompressees = await compute(
          _compresserLot,
          [for (final p in lot) p.imageUrl],
        );
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Compression d\'un lot de photos échouée — ces lignes seront '
          'transmises sans photo, le reste de la tournée continue quand '
          'même',
          tag: 'FirestoreTourRemoteSink',
          error: error,
          stackTrace: stackTrace,
        );
        imagesCompressees = List<String?>.filled(lot.length, null);
      }

      // Écritures du lot en parallèle entre elles (rapide), mais un lot
      // à la fois (borné) — chaque ligne reste isolée dans son propre
      // try/catch : une ligne qui échoue (écriture réseau en erreur) ne
      // doit jamais empêcher la transmission des autres.
      await Future.wait([
        for (var j = 0; j < lot.length; j++)
          _pushLigne(tourId, lot[j], imagesCompressees[j]),
      ]);
    }

    AppLogger.event(
      'Tournée transmise au serveur : $tourId (${produits.length} produits)',
      tag: 'FirestoreTourRemoteSink',
    );
  }

  /// Fonction top-level-compatible (statique, sans état capturé) requise
  /// par [compute] pour s'exécuter dans un isolate séparé — une photo qui
  /// échoue à se compresser ne doit jamais faire échouer les autres du
  /// même lot.
  static List<String?> _compresserLot(List<String?> urls) {
    return [for (final url in urls) _compresserUneSeule(url)];
  }

  static String? _compresserUneSeule(String? url) {
    try {
      return PhotoCompression.compresser(url);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteTour(String tourId) async {
    try {
      final lignes = await _firestore
          .collection(_productLinesCollection)
          .where('tourId', isEqualTo: tourId)
          .get()
          .timeout(const Duration(seconds: 20));

      await Future.wait([
        for (final doc in lignes.docs) doc.reference.delete(),
      ]);

      await _firestore
          .collection(_toursCollection)
          .doc(tourId)
          .delete()
          .timeout(const Duration(seconds: 20));

      AppLogger.event(
        'Tournée supprimée du serveur : $tourId (${lignes.docs.length} lignes)',
        tag: 'FirestoreTourRemoteSink',
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Tournée $tourId non supprimée du serveur — restera visible sur '
        'les autres appareils tant que la suppression n\'a pas réussi',
        tag: 'FirestoreTourRemoteSink',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// [imageUrlCompresse] est déjà prête (voir [_compresserLot], appelée
  /// une fois par lot dans [pushImportedTour]) — cette méthode ne fait
  /// plus que l'écriture réseau.
  Future<void> _pushLigne(
    String tourId,
    TourProductPayload produit,
    String? imageUrlCompresse,
  ) async {
    // Identifiant déterministe (tournée + position) plutôt qu'un UUID :
    // réimporter/republier la même tournée écrase la même ligne au lieu
    // d'en créer une nouvelle en double sur le serveur.
    final ligneId = '$tourId-${produit.ordre}';

    try {
      await _firestore
          .collection(_productLinesCollection)
          .doc(ligneId)
          .set({
            'tourId': tourId,
            'ordre': produit.ordre,
            'nom': produit.nom,
            'description': produit.description,
            'quantiteDemandee': produit.quantiteDemandee,
            'emplacement': produit.emplacement,
            'imageUrl': imageUrlCompresse,
          })
          .timeout(const Duration(seconds: 20));
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Ligne "${produit.nom}" non transmise au serveur — le reste de '
        'la tournée continue quand même',
        tag: 'FirestoreTourRemoteSink',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
