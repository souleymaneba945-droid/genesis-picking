import 'package:genesis_picking/features/courier/data/courier_request.dart';

/// Source distante des demandes coursier destinées à un coursier donné.
///
/// Interface volontairement minimale et indépendante de toute technologie
/// réseau — même principe que `TourRemoteSource` : [CourierService] ne
/// dépend que de cette interface, jamais d'une implémentation concrète.
abstract interface class CourierRequestRemoteSource {
  /// Toutes les demandes connues du serveur pour ce coursier — à charge
  /// de l'appelant de fusionner avec les demandes déjà connues localement
  /// (voir `CourierRepository.upsertFromRemote`).
  Future<List<CourierRequest>> pullForCoursier(String coursierId);

  /// Même contenu que [pullForCoursier], mais en flux continu : émet une
  /// nouvelle liste à chaque changement côté serveur (nouvelle demande
  /// créée par un préparateur, changement d'état...), sans jamais avoir
  /// besoin de rouvrir un écran ou d'appuyer sur "Actualiser" — voir
  /// [CourierService.watchRequestsForCoursier].
  Stream<List<CourierRequest>> watchForCoursier(String coursierId);
}

/// Implémentation "sans source distante active" — utilisée tant que
/// Firebase n'est pas disponible (tests, ou build sans configuration
/// Firebase) : ne renvoie jamais de demande, l'appareil reste alors
/// limité aux demandes créées localement, exactement comme avant
/// l'introduction de la synchronisation réelle.
class NoCourierRequestRemoteSource implements CourierRequestRemoteSource {
  const NoCourierRequestRemoteSource();

  @override
  Future<List<CourierRequest>> pullForCoursier(String coursierId) async {
    return const [];
  }

  @override
  Stream<List<CourierRequest>> watchForCoursier(String coursierId) {
    return Stream.value(const []);
  }
}
