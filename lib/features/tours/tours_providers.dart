import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/sync/firestore/firestore_providers.dart';
import 'package:genesis_picking/features/tours/data/drift_tour_repository.dart';
import 'package:genesis_picking/features/tours/data/firestore_tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_sink.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_repository.dart';
import 'package:genesis_picking/features/tours/domain/tour_service.dart';

final tourRepositoryProvider = Provider<TourRepository>((ref) {
  return DriftTourRepository(ref.watch(localDatabaseProvider));
});

/// Source distante réelle (Firestore) maintenant qu'un backend existe
/// (voir `MODULE_SYNC_REEL.md`) — remplace `NoTourRemoteSource` : une
/// tournée importée sur un appareil (voir [tourRemoteSinkProvider])
/// devient ainsi visible et téléchargeable sur les autres appareils du
/// même compte préparateur.
final tourRemoteSourceProvider = Provider<TourRemoteSource>((ref) {
  return FirestoreTourRemoteSource(ref.watch(firestoreProvider));
});

/// Transmission d'une tournée fraîchement importée vers le serveur — voir
/// `ImportEngine`.
final tourRemoteSinkProvider = Provider<TourRemoteSink>((ref) {
  return FirestoreTourRemoteSink(ref.watch(firestoreProvider));
});

final tourServiceProvider = Provider<TourService>((ref) {
  return TourService(
    repository: ref.watch(tourRepositoryProvider),
    remoteSource: ref.watch(tourRemoteSourceProvider),
    syncQueue: ref.watch(syncQueueProvider),
    remoteSink: ref.watch(tourRemoteSinkProvider),
  );
});

/// Flux "en direct" des tournées d'un préparateur — voir
/// `TourService.watchTours`. Partagé par `PreparateurHomeTab` ET
/// `MyToursScreen` (montés simultanément par `RoleShell` via
/// `IndexedStack`) : les deux restent automatiquement synchronisés entre
/// eux, sans logique de rechargement dupliquée dans chaque écran.
final toursForPreparateurProvider =
    StreamProvider.family<List<Tour>, String>((ref, preparateurId) {
  return ref.watch(tourServiceProvider).watchTours(preparateurId);
});
