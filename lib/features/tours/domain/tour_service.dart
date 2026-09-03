import 'dart:async';
import 'dart:convert';

import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/sync/sync_queue.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_sink.dart';
import 'package:genesis_picking/features/tours/data/tour_repository.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Types d'événements de synchronisation propres aux tournées, déposés
/// dans la file générique posée au Module 1 ([SyncQueue]). Le Module 7
/// leur donnera un traitement réel ; ce module se contente de les
/// enregistrer (Directive Module 3 : "préparer uniquement la structure").
class TourSyncEventTypes {
  TourSyncEventTypes._();

  static const String tourneeTelechargee = 'tournee_telechargee';
  static const String tourneeDebutee = 'tournee_debutee';
  static const String tourneeTerminee = 'tournee_terminee';
}

/// Service métier des tournées.
///
/// Implémente exactement le périmètre de la Directive Module 3:
/// réception (métadonnées), téléchargement (Processus 2), et structure de
/// reprise (Processus 3, au niveau de la tournée uniquement — aucune
/// logique de validation de produit ici, voir Module 4).
class TourService {
  TourService({
    required TourRepository repository,
    required TourRemoteSource remoteSource,
    required SyncEventSink syncQueue,
    required TourRemoteSink remoteSink,
  })  : _repository = repository,
        _remoteSource = remoteSource,
        _syncQueue = syncQueue,
        _remoteSink = remoteSink;

  final TourRepository _repository;
  final TourRemoteSource _remoteSource;
  final SyncEventSink _syncQueue;
  final TourRemoteSink _remoteSink;

  /// Rafraîchit la liste des tournées disponibles pour ce préparateur
  /// (interroge la source distante si possible) puis renvoie la liste
  /// locale complète, offline-first : un échec réseau n'empêche jamais
  /// de consulter les tournées déjà connues localement.
  Future<Result<List<Tour>>> refreshAvailableTours(String preparateurId) async {
    try {
      final availableRemotely = await _remoteSource.listAvailableTours(
        preparateurId,
      );
      for (final entry in availableRemotely) {
        await _repository.registerAvailableTour(
          tourId: entry.tourId,
          numeroTournee: entry.numeroTournee,
          preparateurId: preparateurId,
        );
      }
    } catch (error, stackTrace) {
      // Échec réseau : on continue avec les données locales déjà
      // connues, conformément au principe Offline First. On ne renvoie
      // PAS d'échec ici pour ne jamais bloquer l'écran "Mes tournées".
      AppLogger.warning(
        'Impossible de rafraîchir la liste des tournées, '
        'affichage des données locales existantes',
        tag: 'TourService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final tours = await _repository.listForPreparateur(preparateurId);
    return Result.success(tours);
  }

  /// Flux continu des tournées de ce préparateur — équivalent "en direct"
  /// de [refreshAvailableTours] : émet la liste locale immédiatement
  /// (fonctionne hors-ligne, donnée déjà connue), puis réémet une liste
  /// locale à jour à chaque changement détecté côté serveur (nouvelle
  /// tournée importée, où que ce soit), sans qu'aucun écran n'ait besoin
  /// d'être rouvert ni d'appuyer sur "Actualiser".
  ///
  /// Un souci sur le flux distant (réseau, permissions...) est journalisé
  /// et n'interrompt jamais le flux renvoyé ici : l'écran continue de
  /// fonctionner avec les dernières données locales connues, exactement
  /// comme [refreshAvailableTours] ne bloque jamais l'écran "Mes
  /// tournées" en cas d'échec réseau.
  Stream<List<Tour>> watchTours(String preparateurId) {
    late final StreamController<List<Tour>> controller;
    StreamSubscription<List<({String tourId, String numeroTournee})>>? sub;

    Future<void> emitLocal() async {
      if (controller.isClosed) return;
      controller.add(await _repository.listForPreparateur(preparateurId));
    }

    controller = StreamController<List<Tour>>(
      onListen: () async {
        await emitLocal();
        sub = _remoteSource.watchAvailableTours(preparateurId).listen(
          (distantes) async {
            for (final entry in distantes) {
              try {
                await _repository.registerAvailableTour(
                  tourId: entry.tourId,
                  numeroTournee: entry.numeroTournee,
                  preparateurId: preparateurId,
                );
              } catch (error, stackTrace) {
                AppLogger.warning(
                  'Tournée distante ${entry.tourId} non intégrée localement',
                  tag: 'TourService',
                  error: error,
                  stackTrace: stackTrace,
                );
              }
            }
            await emitLocal();
          },
          onError: (Object error, StackTrace stackTrace) {
            AppLogger.warning(
              'Flux distant des tournées interrompu — les données locales '
              'déjà connues restent affichées',
              tag: 'TourService',
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

  /// Téléchargement complet d'une tournée (Processus 2).
  ///
  /// Idempotent et sans risque de doublon : si la tournée est déjà
  /// téléchargée localement, aucun nouvel appel réseau n'est effectué et
  /// la tournée existante est renvoyée telle quelle — c'est ce mécanisme
  /// qui permet une reprise fiable après une coupure survenue lors d'un
  /// appel précédent.
  Future<Result<Tour>> downloadTour(String tourId) async {
    final existing = await _repository.findById(tourId);
    if (existing != null && existing.estTeleChargeeLocalement) {
      AppLogger.info(
        'Téléchargement déjà effectué, aucune action réseau : $tourId',
        tag: 'TourService',
      );
      return Result.success(existing);
    }

    final TourDownloadPayload payload;
    try {
      payload = await _remoteSource.fetchTourContent(tourId);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Échec du téléchargement (réseau) : $tourId',
        tag: 'TourService',
        error: error,
        stackTrace: stackTrace,
      );
      return Result.failure(
        NetworkException(
          'Pas de connexion. Votre travail est enregistré et sera transmis '
          'automatiquement.',
          cause: error,
        ),
      );
    }

    final integrityError = _checkIntegrity(payload);
    if (integrityError != null) {
      AppLogger.error(
        'Échec d\'intégrité du contenu téléchargé : $tourId — $integrityError',
        tag: 'TourService',
      );
      return Result.failure(ValidationException(integrityError));
    }

    final saved = await _repository.saveDownloadedTour(
      tourId: payload.tourId,
      numeroTournee: payload.numeroTournee,
      preparateurId: payload.preparateurId,
      produits: payload.produits,
    );

    // Contrôle d'intégrité après écriture : le nombre de lignes
    // réellement stockées doit correspondre exactement au contenu reçu.
    final storedCount = await _repository.countProductLines(tourId);
    if (storedCount != payload.produits.length) {
      return Result.failure(
        StorageException(
          'Le stockage local de la tournée est incomplet '
          '($storedCount/${payload.produits.length} produits).',
        ),
      );
    }

    await _syncQueue.enqueue(
      eventType: TourSyncEventTypes.tourneeTelechargee,
      payload: jsonEncode({
        'tourId': saved.id,
        'numeroTournee': saved.numeroTournee,
        'nombreTotalProduits': saved.nombreTotalProduits,
      }),
    );

    return Result.success(saved);
  }

  /// Démarre ou reprend la préparation d'une tournée déjà téléchargée
  /// (Processus 3, au niveau de la tournée uniquement — aucun produit
  /// n'est présenté ici, voir Module 4).
  ///
  /// Si la tournée est déjà "En cours", ce n'est pas un redémarrage : la
  /// progression déjà enregistrée est conservée telle quelle — c'est
  /// exactement la garantie de reprise exigée par la Directive Module 3.
  Future<Result<Tour>> startOrResume(String tourId) async {
    final tour = await _repository.findById(tourId);
    if (tour == null) {
      return const Result.failure(ValidationException('Tournée introuvable.'));
    }

    switch (tour.statut) {
      case TourStatus.disponible:
        return const Result.failure(
          ValidationException(
            'Cette tournée doit d\'abord être téléchargée.',
          ),
        );
      case TourStatus.telechargee:
        await _repository.updateStatus(
          tourId: tourId,
          statut: TourStatus.enCours,
        );
        await _syncQueue.enqueue(
          eventType: TourSyncEventTypes.tourneeDebutee,
          payload: jsonEncode({'tourId': tourId}),
        );
        return Result.success(tour.copyWith(statut: TourStatus.enCours));
      case TourStatus.enCours:
        // Reprise : rien à modifier, la progression existante est déjà
        // celle à laquelle le préparateur doit revenir.
        AppLogger.info('Reprise de la tournée $tourId', tag: 'TourService');
        return Result.success(tour);
      case TourStatus.terminee:
        return const Result.failure(
          ValidationException('Cette tournée est déjà terminée.'),
        );
    }
  }

  /// Clôture une tournée. Réservé à l'usage du Module 4 : c'est à lui de
  /// vérifier que chaque produit a un état final avant d'appeler cette
  /// méthode (Processus 8). Ce service applique uniquement le garde-fou
  /// structurel déjà prévu par le PRG (« une tournée ne peut être
  /// clôturée si un seul produit n'a pas d'état final ») via la
  /// comparaison des compteurs, sans connaître la moindre règle de
  /// validation produit par produit.
  Future<Result<Tour>> completeTour(String tourId) async {
    final tour = await _repository.findById(tourId);
    if (tour == null) {
      return const Result.failure(ValidationException('Tournée introuvable.'));
    }
    if (tour.produitsTraites < tour.nombreTotalProduits) {
      return const Result.failure(
        ValidationException(
          'Un produit n\'a pas encore d\'état défini.',
        ),
      );
    }

    await _repository.updateStatus(tourId: tourId, statut: TourStatus.terminee);
    await _syncQueue.enqueue(
      eventType: TourSyncEventTypes.tourneeTerminee,
      payload: jsonEncode({'tourId': tourId}),
    );
    return Result.success(tour.copyWith(statut: TourStatus.terminee));
  }

  /// Supprime définitivement une tournée — pour corriger un import
  /// erroné (numéro de tournée incorrect, mauvais préparateur, doublon...).
  /// Local d'abord, puis serveur (best-effort mais indispensable ici, voir
  /// [TourRemoteSink.deleteTour] : sans lui, la tournée réapparaîtrait
  /// comme "disponible" au prochain rafraîchissement).
  Future<Result<void>> deleteTour(String tourId) async {
    final tour = await _repository.findById(tourId);
    if (tour == null) {
      return const Result.failure(ValidationException('Tournée introuvable.'));
    }

    await _repository.delete(tourId);
    await _remoteSink.deleteTour(tourId);

    AppLogger.event(
      'Tournée ${tour.numeroTournee} ($tourId) supprimée',
      tag: 'TourService',
    );
    return const Result.success(null);
  }

  String? _checkIntegrity(TourDownloadPayload payload) {
    if (payload.numeroTournee.trim().isEmpty) {
      return 'Numéro de tournée manquant.';
    }
    if (payload.produits.isEmpty) {
      return 'La tournée ne contient aucun produit.';
    }
    for (final produit in payload.produits) {
      if (produit.nom.trim().isEmpty) {
        return 'Un produit sans nom a été détecté.';
      }
      if (produit.quantiteDemandee <= 0) {
        return 'Quantité invalide pour le produit "${produit.nom}".';
      }
    }
    return null;
  }
}
