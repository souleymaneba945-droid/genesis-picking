import 'package:genesis_picking/core/sync/sync_manager.dart';

/// Contrat minimal pour savoir si l'appareil est actuellement en ligne.
///
/// Extrait pour permettre une implémentation contrôlable dans les tests
/// (Directive : "fonctionnement hors connexion" doit être testable) sans
/// dépendre du [SyncManager] concret ni de `connectivity_plus`.
abstract interface class CourierAvailabilityChecker {
  bool get isOnline;
}

/// Implémentation réelle : s'appuie sur le [SyncManager] déjà posé au
/// Module 1, qui suit déjà l'état réseau — aucune nouvelle dépendance
/// réseau n'a été ajoutée pour ce module.
class SyncManagerAvailabilityChecker implements CourierAvailabilityChecker {
  SyncManagerAvailabilityChecker(this._syncManager);

  final SyncManager _syncManager;

  @override
  bool get isOnline => _syncManager.currentState != SyncState.offline;
}
