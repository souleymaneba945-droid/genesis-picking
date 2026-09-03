import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/features/sync/data/drift_sync_repository.dart';
import 'package:genesis_picking/features/sync/data/sync_repository.dart';
import 'package:genesis_picking/features/sync/data/sync_transport.dart';
import 'package:genesis_picking/features/sync/domain/conflict_resolver.dart';
import 'package:genesis_picking/features/sync/domain/sync_service.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return DriftSyncRepository(ref.watch(localDatabaseProvider));
});

/// Implémentation de démonstration tant qu'aucun backend réel n'existe
/// (voir justification dans `sync_transport.dart`). Remplacer uniquement
/// ce provider suffira à brancher un vrai serveur plus tard.
final syncTransportProvider = Provider<SyncTransport>((ref) {
  return SimulatedSyncTransport();
});

final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    repository: ref.watch(syncRepositoryProvider),
    transport: ref.watch(syncTransportProvider),
    networkMonitor: ref.watch(networkMonitorProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
