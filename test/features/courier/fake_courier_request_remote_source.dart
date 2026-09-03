import 'dart:async';

import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_remote_source.dart';

/// Implémentation en mémoire de [CourierRequestRemoteSource], pour
/// simuler des demandes créées par un préparateur sur un AUTRE appareil,
/// à découvrir lors de [CourierService.listRequestsForCoursier] (ou, en
/// direct, [CourierService.watchRequestsForCoursier]).
class FakeCourierRequestRemoteSource implements CourierRequestRemoteSource {
  final List<CourierRequest> remoteRequests = [];

  /// Simule une panne réseau (le service doit alors continuer avec les
  /// demandes déjà connues localement — voir `CourierService`).
  bool pannePersistante = false;

  final _streamController = StreamController<List<CourierRequest>>.broadcast();

  @override
  Future<List<CourierRequest>> pullForCoursier(String coursierId) async {
    if (pannePersistante) {
      throw Exception('Panne réseau simulée');
    }
    return remoteRequests.where((r) => r.coursierId == coursierId).toList();
  }

  @override
  Stream<List<CourierRequest>> watchForCoursier(String coursierId) {
    return _streamController.stream;
  }

  /// Simule un événement Firestore "en direct" (nouvelle demande créée
  /// par un préparateur ailleurs, ou mise à jour d'état) — pousse
  /// manuellement une liste sur le flux écouté par [watchForCoursier].
  void emitRequests(List<CourierRequest> requests) {
    _streamController.add(requests);
  }

  /// Simule une panne du flux distant — `CourierService.watchRequestsForCoursier`
  /// doit alors continuer avec les demandes locales déjà connues, jamais
  /// interrompre le flux qu'il renvoie à l'écran.
  void emitWatchError(Object error) {
    _streamController.addError(error, StackTrace.current);
  }
}
