import 'dart:async';
import 'dart:convert';

import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/activity/activity_log.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/sync/sync_queue.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';
import 'package:genesis_picking/features/courier/data/courier_availability_checker.dart';
import 'package:genesis_picking/features/courier/data/courier_repository.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_detail_view.dart';
import 'package:genesis_picking/features/courier/data/courier_request_remote_sink.dart';
import 'package:genesis_picking/features/courier/data/courier_request_remote_source.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/courier/data/courier_request_summary.dart';
import 'package:genesis_picking/features/courier/data/courier_summary.dart';
import 'package:genesis_picking/features/picking/data/product_repository.dart';

/// Types d'événements de synchronisation propres aux demandes coursier,
/// déposés dans la file générique du Module 1 (structure uniquement —
/// la transmission réelle reste au Module 7).
class CourierSyncEventTypes {
  CourierSyncEventTypes._();

  static const String demandeCreee = 'demande_coursier_creee';
  static const String demandeTraitee = 'demande_coursier_traitee';
}

/// Service métier des demandes coursier.
///
/// Ne modifie jamais le moteur de picking : la seule interaction avec lui
/// se fait via `PickingController.marquerEnvoyeAuCoursier`, appelée par
/// l'écran (voir `courier_selection_screen.dart`), jamais par ce service.
class CourierService {
  CourierService({
    required CourierRepository courierRepository,
    required UserRepository userRepository,
    required ProductRepository productRepository,
    required CourierAvailabilityChecker availabilityChecker,
    required SyncEventSink syncQueue,
    required ActivityLogSink activityLogSink,
    required CourierRequestRemoteSink remoteSink,
    required CourierRequestRemoteSource remoteSource,
  })  : _courierRepository = courierRepository,
        _userRepository = userRepository,
        _productRepository = productRepository,
        _availabilityChecker = availabilityChecker,
        _syncQueue = syncQueue,
        _activityLogSink = activityLogSink,
        _remoteSink = remoteSink,
        _remoteSource = remoteSource;

  final CourierRepository _courierRepository;
  final UserRepository _userRepository;
  final ProductRepository _productRepository;
  final CourierAvailabilityChecker _availabilityChecker;
  final SyncEventSink _syncQueue;
  final ActivityLogSink _activityLogSink;

  /// Transmission des demandes vers le serveur central (création, mises à
  /// jour d'état) — voir `courier_request_remote_sink.dart`.
  final CourierRequestRemoteSink _remoteSink;

  /// Réception des demandes créées sur d'autres appareils — voir
  /// `courier_request_remote_source.dart`, interrogée dans
  /// [listRequestsForCoursier].
  final CourierRequestRemoteSource _remoteSource;

  /// Coursiers actifs uniquement, avec leur nombre de demandes ouvertes
  /// (Directive, "Choix du coursier").
  Future<List<CourierSummary>> listActiveCouriers() async {
    final users = await _userRepository.listAll();
    final coursiers = users.where(
      (u) => u.role == UserRole.coursier && u.actif,
    );

    final summaries = <CourierSummary>[];
    for (final coursier in coursiers) {
      final ouvertes = await _courierRepository.countOpenRequestsFor(
        coursier.id,
      );
      summaries.add(
        CourierSummary(
          id: coursier.id,
          nom: coursier.nomAffichage,
          demandesEnAttente: ouvertes,
        ),
      );
    }
    return summaries;
  }

  /// Création d'une demande (Directive, "Création d'une demande").
  ///
  /// Démarre toujours à l'état Créée, puis passe immédiatement à Reçue
  /// (coursier joignable) ou En attente (hors connexion) — c'est ce
  /// second cas qui permet le fonctionnement hors connexion avec
  /// synchronisation ultérieure exigé par la Directive.
  Future<Result<CourierRequest>> createRequest({
    required String preparateurId,
    required String coursierId,
    required String tourId,
    required String productLineId,
    required int quantiteDemandee,
    required String emplacement,
  }) async {
    // Instantané produit pris ICI, sur l'appareil du préparateur qui
    // envoie la demande (toujours équipé de la tournée en local) — voir
    // `CourierRequestsTable` pour le pourquoi : c'est ce qui permet à
    // l'appareil du coursier, qui n'a jamais téléchargé cette tournée,
    // d'afficher quand même le nom/la description/la photo du produit une
    // fois la demande synchronisée.
    final produit = await _productRepository.findById(productLineId);

    final created = await _courierRepository.create(
      preparateurId: preparateurId,
      coursierId: coursierId,
      tourId: tourId,
      productLineId: productLineId,
      quantiteDemandee: quantiteDemandee,
      emplacement: emplacement,
      produitNom: produit?.nom,
      produitDescription: produit?.description,
      produitImageUrl: produit?.imageUrl,
    );

    final etatSuivant = _availabilityChecker.isOnline
        ? CourierRequestStatus.recue
        : CourierRequestStatus.enAttente;

    await _courierRepository.updateStatus(
      requestId: created.id,
      etat: etatSuivant,
    );

    await _syncQueue.enqueue(
      eventType: CourierSyncEventTypes.demandeCreee,
      payload: jsonEncode({
        'requestId': created.id,
        'coursierId': coursierId,
        'productLineId': productLineId,
      }),
    );

    final result = (await _courierRepository.findById(created.id))!;
    // Best-effort, jamais bloquant (voir `FirestoreCourierRequestRemoteSink`) :
    // la demande est déjà acquise localement, sa transmission ne doit
    // jamais faire échouer la création elle-même.
    await _remoteSink.pushRequest(result);
    return Result.success(result);
  }

  /// Liste des demandes d'un coursier, triées par priorité (la plus
  /// ancienne en premier). Fait d'abord passer toute demande "En attente"
  /// à "Reçue" si l'appareil est désormais en ligne — c'est le mécanisme
  /// de synchronisation ultérieure exigé par la Directive : rien ne se
  /// perd pendant la coupure, tout devient visible dès le retour réseau.
  Future<List<CourierRequest>> listRequestsForCoursier(
    String coursierId,
  ) async {
    if (_availabilityChecker.isOnline) {
      // Récupère d'abord les demandes créées par des préparateurs sur
      // D'AUTRES appareils (voir `CourierRequestRemoteSource`) — c'est ce
      // qui fait qu'un coursier voit tout ce qui lui a été envoyé, peu
      // importe l'appareil utilisé par chaque préparateur pour l'envoyer.
      // Best-effort : un échec réseau laisse simplement les demandes déjà
      // connues localement, jamais un blocage de l'écran.
      try {
        final distantes = await _remoteSource.pullForCoursier(coursierId);
        for (final request in distantes) {
          await _courierRepository.upsertFromRemote(request);
        }
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Impossible de récupérer les demandes du serveur, affichage '
          'des demandes déjà connues localement',
          tag: 'CourierService',
          error: error,
          stackTrace: stackTrace,
        );
      }

      final current = await _courierRepository.listForCoursier(coursierId);
      for (final request in current) {
        if (request.etat == CourierRequestStatus.enAttente) {
          await _courierRepository.updateStatus(
            requestId: request.id,
            etat: CourierRequestStatus.recue,
          );
        }
      }
    }
    return _courierRepository.listForCoursier(coursierId);
  }

  /// Flux continu des demandes de ce coursier — équivalent "en direct" de
  /// [listRequestsForCoursier] : émet la liste locale immédiatement
  /// (fonctionne hors-ligne), puis réémet une liste locale à jour à
  /// chaque changement détecté côté serveur (nouvelle demande créée par
  /// un préparateur, où que ce soit), sans qu'aucun écran n'ait besoin
  /// d'être rouvert ni d'appuyer sur "Actualiser" — c'est le point le
  /// plus sensible en pratique : le coursier doit voir une nouvelle
  /// demande arriver quasiment tout de suite.
  ///
  /// Un souci sur le flux distant (réseau, permissions...) est journalisé
  /// et n'interrompt jamais le flux renvoyé ici : l'écran continue de
  /// fonctionner avec les dernières demandes locales connues.
  Stream<List<CourierRequest>> watchRequestsForCoursier(String coursierId) {
    late final StreamController<List<CourierRequest>> controller;
    StreamSubscription<List<CourierRequest>>? sub;

    Future<void> emitLocal() async {
      if (controller.isClosed) return;
      final current = await _courierRepository.listForCoursier(coursierId);
      for (final request in current) {
        if (request.etat == CourierRequestStatus.enAttente &&
            _availabilityChecker.isOnline) {
          await _courierRepository.updateStatus(
            requestId: request.id,
            etat: CourierRequestStatus.recue,
          );
        }
      }
      controller.add(await _courierRepository.listForCoursier(coursierId));
    }

    controller = StreamController<List<CourierRequest>>(
      onListen: () async {
        await emitLocal();
        sub = _remoteSource.watchForCoursier(coursierId).listen(
          (distantes) async {
            for (final request in distantes) {
              try {
                await _courierRepository.upsertFromRemote(request);
              } catch (error, stackTrace) {
                AppLogger.warning(
                  'Demande distante ${request.id} non intégrée localement',
                  tag: 'CourierService',
                  error: error,
                  stackTrace: stackTrace,
                );
              }
            }
            await emitLocal();
          },
          onError: (Object error, StackTrace stackTrace) {
            AppLogger.warning(
              'Flux distant des demandes interrompu — les demandes '
              'locales déjà connues restent affichées',
              tag: 'CourierService',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Ouverture d'une demande par le coursier (Directive, "Traitement") :
  /// fait passer la demande à "Acceptée" (si elle ne l'est pas déjà) et
  /// renvoie la vue enrichie (photo, nom, description/SKU, quantité,
  /// emplacement, préparateur demandeur) — identique à ce que le
  /// préparateur voit sur sa liste de picking, jamais une présentation
  /// appauvrie : la donnée vient toujours du même produit source
  /// ([ProductRepository.findById]), jamais recopiée ni modifiée.
  Future<Result<CourierRequestDetailView>> openRequest(String requestId) async {
    final request = await _courierRepository.findById(requestId);
    if (request == null) {
      return const Result.failure(ValidationException('Demande introuvable.'));
    }

    final futAccepteeIci = request.etat == CourierRequestStatus.recue ||
        request.etat == CourierRequestStatus.enAttente;
    if (futAccepteeIci) {
      await _courierRepository.updateStatus(
        requestId: requestId,
        etat: CourierRequestStatus.acceptee,
        dateAcceptation: DateTime.now(),
      );
    }

    final updated = (await _courierRepository.findById(requestId))!;
    if (futAccepteeIci) {
      await _remoteSink.pushRequest(updated);
    }
    // La jointure locale reste tentée en premier repli pour les demandes
    // créées avant schéma 9 (instantané absent) ; sur toute demande
    // récente, l'instantané pris à la création (voir `createRequest`)
    // suffit à lui seul, y compris sur un appareil qui n'a jamais
    // téléchargé la tournée (le coursier, typiquement).
    final produit = await _productRepository.findById(request.productLineId);
    final preparateur = await _findUserDisplayName(request.preparateurId);

    return Result.success(
      CourierRequestDetailView(
        request: updated,
        produitNom: updated.produitNom ?? produit?.nom ?? 'Produit',
        produitDescription: updated.produitDescription ?? produit?.description,
        produitImageUrl: updated.produitImageUrl ?? produit?.imageUrl,
        preparateurNom: preparateur ?? 'Préparateur',
      ),
    );
  }

  /// Réponse du coursier (Directive, "Aucun autre choix" que retrouvé ou
  /// non retrouvé). Fait passer la demande à "Traitée".
  Future<Result<CourierRequest>> respond({
    required String requestId,
    required CourierRequestResult resultat,
  }) async {
    final request = await _courierRepository.findById(requestId);
    if (request == null) {
      return const Result.failure(ValidationException('Demande introuvable.'));
    }
    if (request.etat != CourierRequestStatus.acceptee) {
      return const Result.failure(
        ValidationException(
          'Cette demande doit être ouverte avant d\'être traitée.',
        ),
      );
    }

    await _courierRepository.updateStatus(
      requestId: requestId,
      etat: CourierRequestStatus.traitee,
      resultat: resultat,
      dateTraitement: DateTime.now(),
    );

    await _syncQueue.enqueue(
      eventType: CourierSyncEventTypes.demandeTraitee,
      payload: jsonEncode({'requestId': requestId, 'resultat': resultat.name}),
    );

    AppLogger.event(
      'Demande $requestId traitée par le coursier → $resultat',
      tag: 'CourierService',
    );

    final produit = await _productRepository.findById(request.productLineId);
    final nomProduit = request.produitNom ?? produit?.nom ?? 'Produit';
    await _activityLogSink.record(
      userId: request.coursierId,
      level: resultat == CourierRequestResult.retrouve
          ? ActivityLevel.succes
          : ActivityLevel.avertissement,
      message: resultat == CourierRequestResult.retrouve
          ? '$nomProduit retrouvé pour le préparateur'
          : '$nomProduit non retrouvé',
    );

    final updated = (await _courierRepository.findById(requestId))!;
    await _remoteSink.pushRequest(updated);
    return Result.success(updated);
  }

  /// Demandes envoyées par ce préparateur (Directive, "Retour
  /// préparateur") : toute demande "Traitée" non encore clôturée est
  /// automatiquement close ("Terminée") au moment où le préparateur la
  /// consulte — c'est ce qui matérialise "le préparateur reçoit
  /// immédiatement la mise à jour".
  Future<List<CourierRequest>> listRequestsForPreparateur(
    String preparateurId,
  ) async {
    final current = await _courierRepository.listForPreparateur(preparateurId);
    for (final request in current) {
      if (request.etat == CourierRequestStatus.traitee) {
        await _courierRepository.updateStatus(
          requestId: request.id,
          etat: CourierRequestStatus.terminee,
          dateCloture: DateTime.now(),
        );
      }
    }
    return _courierRepository.listForPreparateur(preparateurId);
  }

  /// Mêmes demandes que [listRequestsForCoursier] (même tri, même effet
  /// de bord "En attente" → "Reçue"), chacune accompagnée du nom
  /// d'affichage du préparateur qui l'a envoyée — pour que l'écran puisse
  /// les regrouper par préparateur (le terrain veut voir "tout ce que
  /// Fatou m'a envoyé" en un coup d'œil) sans avoir à connaître
  /// [UserRepository] lui-même — et du nom, de la description/SKU et de
  /// la photo du produit concerné, pour que la liste des missions du
  /// coursier affiche exactement la même identification produit que
  /// l'écran de picking du préparateur (jamais une simple liste de
  /// statuts sans image ni référence : le coursier s'en sert pour
  /// retrouver le produit). Une seule requête sur les comptes, jamais une
  /// par demande ; le produit reste recherché par demande (pas de méthode
  /// de lecture groupée sur [ProductRepository] aujourd'hui).
  Future<List<CourierRequestSummary>> listRequestsForCoursierWithPreparateur(
    String coursierId,
  ) async {
    final requests = await listRequestsForCoursier(coursierId);
    if (requests.isEmpty) return const [];

    final users = await _userRepository.listAll();
    final nomParId = {for (final u in users) u.id: u.nomAffichage};

    final enrichies = <CourierRequestSummary>[];
    for (final r in requests) {
      // Voir `openRequest` : instantané pris à la création en premier,
      // jointure locale seulement en repli (demandes créées avant schéma 9,
      // ou instantané absent pour une autre raison).
      final produit = await _productRepository.findById(r.productLineId);
      enrichies.add(
        CourierRequestSummary(
          request: r,
          preparateurNom: nomParId[r.preparateurId] ?? 'Préparateur',
          produitNom: r.produitNom ?? produit?.nom ?? 'Produit',
          produitDescription: r.produitDescription ?? produit?.description,
          produitImageUrl: r.produitImageUrl ?? produit?.imageUrl,
        ),
      );
    }
    return enrichies;
  }

  /// Supprime définitivement une demande — pour corriger une erreur
  /// d'envoi (mauvais coursier, doublon...) ou faire le ménage dans une
  /// demande déjà traitée. Local d'abord, puis serveur (best-effort mais
  /// indispensable ici, voir [CourierRequestRemoteSink.deleteRequest] :
  /// sans lui, la demande reviendrait au prochain rafraîchissement).
  Future<Result<void>> deleteRequest(String requestId) async {
    final request = await _courierRepository.findById(requestId);
    if (request == null) {
      return const Result.failure(ValidationException('Demande introuvable.'));
    }

    await _courierRepository.delete(requestId);
    await _remoteSink.deleteRequest(requestId);

    AppLogger.event('Demande $requestId supprimée', tag: 'CourierService');
    return const Result.success(null);
  }

  /// Supprime en une fois toutes les demandes déjà closes ("Traitée" ou
  /// "Terminée") de ce coursier — ménage rapide sur un historique qui
  /// s'accumule, sans avoir à ouvrir chaque demande une par une. Réutilise
  /// [deleteRequest] demande par demande : une demande qui échoue à se
  /// supprimer du serveur (réseau) n'empêche jamais les suivantes.
  Future<void> purgeClosedForCoursier(String coursierId) async {
    final requests = await _courierRepository.listForCoursier(coursierId);
    for (final r in requests) {
      if (!r.estOuverte) {
        await deleteRequest(r.id);
      }
    }
  }

  Future<String?> _findUserDisplayName(String userId) async {
    final users = await _userRepository.listAll();
    for (final user in users) {
      if (user.id == userId) {
        return user.nomAffichage;
      }
    }
    return null;
  }
}
