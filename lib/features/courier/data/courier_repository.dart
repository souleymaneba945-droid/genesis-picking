import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Contrat abstrait d'accès aux demandes coursier. [CourierService] ne
/// dépend que de cette interface, jamais de Drift directement — même
/// principe que le reste du projet.
abstract interface class CourierRepository {
  Future<CourierRequest> create({
    required String preparateurId,
    required String coursierId,
    required String tourId,
    required String productLineId,
    required int quantiteDemandee,
    required String emplacement,
    String? produitNom,
    String? produitDescription,
    String? produitImageUrl,
  });

  Future<CourierRequest?> findById(String requestId);

  /// Demandes assignées à ce coursier, triées par date de création
  /// croissante (la plus ancienne = priorité la plus haute).
  Future<List<CourierRequest>> listForCoursier(String coursierId);

  /// Demandes créées par ce préparateur, les plus récentes en premier
  /// (Directive, "Retour préparateur").
  Future<List<CourierRequest>> listForPreparateur(String preparateurId);

  /// Toutes les demandes, tous préparateurs et coursiers confondus
  /// (Module 8 — Administration). Ajouté de façon strictement additive.
  Future<List<CourierRequest>> listAll();

  /// Nombre de demandes encore ouvertes (non traitées/terminées) pour ce
  /// coursier — utilisé par l'écran "Choix du coursier".
  Future<int> countOpenRequestsFor(String coursierId);

  Future<void> updateStatus({
    required String requestId,
    required CourierRequestStatus etat,
    CourierRequestResult? resultat,
    DateTime? dateAcceptation,
    DateTime? dateTraitement,
    DateTime? dateCloture,
  });

  /// Insère ou remplace intégralement une demande reçue du serveur central
  /// (voir `CourierRequestRemoteSource`) — même principe que
  /// `UserRepository.upsertFromRemote` : une demande créée par un
  /// préparateur sur UN appareil doit devenir visible sur l'appareil du
  /// coursier concerné, quel qu'il soit.
  Future<void> upsertFromRemote(CourierRequest request);

  /// Supprime définitivement une demande — pour corriger une erreur
  /// d'envoi ou faire le ménage dans un historique déjà traité.
  Future<void> delete(String requestId);
}
