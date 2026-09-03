import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/sync/firestore/firestore_providers.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_availability_checker.dart';
import 'package:genesis_picking/features/courier/data/courier_repository.dart';
import 'package:genesis_picking/features/courier/data/courier_request_remote_sink.dart';
import 'package:genesis_picking/features/courier/data/courier_request_remote_source.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/drift_courier_repository.dart';
import 'package:genesis_picking/features/courier/data/firestore_courier_request_remote_source.dart';
import 'package:genesis_picking/features/courier/domain/courier_service.dart';
import 'package:genesis_picking/features/picking/picking_providers.dart';

final courierRepositoryProvider = Provider<CourierRepository>((ref) {
  return DriftCourierRepository(ref.watch(localDatabaseProvider));
});

final courierAvailabilityCheckerProvider = Provider<CourierAvailabilityChecker>((
  ref,
) {
  return SyncManagerAvailabilityChecker(ref.watch(syncManagerProvider));
});

/// Transmission d'une demande fraîchement créée/mise à jour vers le
/// serveur — voir `CourierService`.
final courierRequestRemoteSinkProvider = Provider<CourierRequestRemoteSink>((
  ref,
) {
  return FirestoreCourierRequestRemoteSink(ref.watch(firestoreProvider));
});

/// Réception des demandes créées par un préparateur sur un AUTRE appareil
/// — remplace `NoCourierRequestRemoteSource` maintenant qu'un vrai
/// backend existe (voir `MODULE_SYNC_REEL.md`).
final courierRequestRemoteSourceProvider = Provider<CourierRequestRemoteSource>((
  ref,
) {
  return FirestoreCourierRequestRemoteSource(ref.watch(firestoreProvider));
});

final courierServiceProvider = Provider<CourierService>((ref) {
  return CourierService(
    courierRepository: ref.watch(courierRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
    availabilityChecker: ref.watch(courierAvailabilityCheckerProvider),
    syncQueue: ref.watch(syncQueueProvider),
    activityLogSink: ref.watch(activityLogRepositoryProvider),
    remoteSink: ref.watch(courierRequestRemoteSinkProvider),
    remoteSource: ref.watch(courierRequestRemoteSourceProvider),
  );
});

/// Flux brut (demandes locales, pas encore enrichies du nom du produit/du
/// préparateur) des demandes de ce coursier — voir
/// `CourierService.watchRequestsForCoursier`. [CourierController] s'y
/// abonne (`ref.listen`) uniquement pour savoir QUAND se rafraîchir,
/// jamais pour lire directement cette valeur : l'enrichissement et la
/// présentation restent entièrement de son ressort, inchangés.
final courierRequestsWatchProvider =
    StreamProvider.family<List<CourierRequest>, String>((ref, coursierId) {
  return ref.watch(courierServiceProvider).watchRequestsForCoursier(coursierId);
});
