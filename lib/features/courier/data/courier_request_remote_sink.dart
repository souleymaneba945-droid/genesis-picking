import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/sync/photo_compression.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';

/// Point d'entrée en écriture, côté service, vers le serveur central —
/// symétrique de [CourierRequestRemoteSource] (lecture). Appelé par
/// `CourierService` après chaque écriture locale réussie (création,
/// changement d'état) : même principe additif et best-effort que
/// `TourRemoteSink`/`SyncingUserRepository` — un échec réseau ici ne
/// remet jamais en cause l'écriture locale déjà faite.
abstract interface class CourierRequestRemoteSink {
  Future<void> pushRequest(CourierRequest request);

  /// Supprime une demande du serveur — appelée par
  /// [CourierService.deleteRequest] juste après la suppression locale.
  /// Indispensable, pas optionnelle : sans elle, le document Firestore
  /// survivrait et reviendrait au prochain `pullForCoursier` (voir
  /// `CourierService.listRequestsForCoursier`, qui réinsère localement
  /// toute demande distante trouvée pour ce coursier).
  Future<void> deleteRequest(String requestId);
}

/// Implémentation "sans destination" — utilisée tant que Firebase n'est
/// pas disponible (tests, ou build sans configuration Firebase).
class NoCourierRequestRemoteSink implements CourierRequestRemoteSink {
  const NoCourierRequestRemoteSink();

  @override
  Future<void> pushRequest(CourierRequest request) async {}

  @override
  Future<void> deleteRequest(String requestId) async {}
}

/// Transmet une demande coursier (création ou mise à jour d'état) vers
/// Firestore — c'est ce qui permet à une demande créée par un préparateur
/// sur UN appareil d'atteindre le téléphone du coursier concerné, quel
/// que soit l'appareil sur lequel celui-ci s'est connecté.
class FirestoreCourierRequestRemoteSink implements CourierRequestRemoteSink {
  FirestoreCourierRequestRemoteSink(this._firestore);

  final FirebaseFirestore _firestore;

  static const _collection = 'courier_requests';

  @override
  Future<void> pushRequest(CourierRequest request) async {
    // Instantané produit compressé (voir `PhotoCompression`) — c'est ce qui
    // permet à l'appareil du coursier, qui n'a jamais téléchargé la
    // tournée, d'afficher quand même le nom/la description/la photo :
    // tout arrive dans le même document, sans jointure locale requise.
    String? imageUrl;
    try {
      imageUrl = PhotoCompression.compresser(request.produitImageUrl);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Photo produit non compressée pour la demande ${request.id} — le '
        'reste de la demande est transmis quand même',
        tag: 'FirestoreCourierRequestRemoteSink',
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await _firestore
          .collection(_collection)
          .doc(request.id)
          .set({
            'preparateurId': request.preparateurId,
            'coursierId': request.coursierId,
            'tourId': request.tourId,
            'productLineId': request.productLineId,
            'quantiteDemandee': request.quantiteDemandee,
            'emplacement': request.emplacement,
            'dateCreation': request.dateCreation.toIso8601String(),
            'etat': request.etat.name,
            'resultat': request.resultat?.name,
            'dateAcceptation': request.dateAcceptation?.toIso8601String(),
            'dateTraitement': request.dateTraitement?.toIso8601String(),
            'dateCloture': request.dateCloture?.toIso8601String(),
            'produitNom': request.produitNom,
            'produitDescription': request.produitDescription,
            'produitImageUrl': imageUrl,
          })
          .timeout(const Duration(seconds: 20));
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Demande ${request.id} non transmise au serveur — reste acquise '
        'localement, sera à refaire manuellement ou au prochain envoi',
        tag: 'FirestoreCourierRequestRemoteSink',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .delete()
          .timeout(const Duration(seconds: 20));
      AppLogger.event(
        'Demande supprimée du serveur : $requestId',
        tag: 'FirestoreCourierRequestRemoteSink',
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Demande $requestId non supprimée du serveur — reviendra au '
        'prochain rafraîchissement tant que la suppression n\'a pas réussi',
        tag: 'FirestoreCourierRequestRemoteSink',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
