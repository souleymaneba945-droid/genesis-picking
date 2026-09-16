import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';

/// Contrat abstrait d'accès aux correspondances marque → emplacement
/// entrepôt (Module 5 v2, Rubrique 2) — même principe que
/// `UserRepository` : l'écran de gestion et [WarehouseLocationService] ne
/// dépendent que de cette interface, jamais directement de Drift.
abstract interface class BrandWarehouseLocationRepository {
  Future<List<BrandWarehouseLocation>> listAll();

  /// Échoue si [marque] existe déjà (comparaison insensible à la casse) —
  /// même principe que `UserRepository.create` sur `identifiant`.
  Future<Result<BrandWarehouseLocation>> create({
    required String marque,
    required String emplacement,
  });

  Future<Result<void>> update({
    required String id,
    required String marque,
    required String emplacement,
  });

  Future<Result<void>> delete(String id);

  /// Insère ou met à jour une correspondance déjà connue ailleurs (reçue
  /// du serveur central) — additif, réservé à la synchronisation (voir
  /// `SyncingBrandWarehouseLocationRepository`), même principe que
  /// `UserRepository.upsertFromRemote`.
  Future<void> upsertFromRemote({
    required String id,
    required String marque,
    required String emplacement,
  });
}
