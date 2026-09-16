/// Une correspondance marque → emplacement telle qu'échangée avec le
/// serveur central.
class BrandWarehouseLocationRemoteRecord {
  const BrandWarehouseLocationRemoteRecord({
    required this.id,
    required this.marque,
    required this.emplacement,
  });

  final String id;
  final String marque;
  final String emplacement;
}

/// Point d'échange des correspondances marque → emplacement avec le
/// serveur central — symétrique de `UserRemoteRepository` : un `push`
/// après chaque écriture locale (création, modification, suppression), un
/// `pullAll` pour que chaque appareil (coursier compris) connaisse la
/// même cartographie entrepôt, maintenue par l'administrateur.
abstract interface class BrandWarehouseLocationRemoteRepository {
  Future<void> push(BrandWarehouseLocationRemoteRecord record);

  Future<void> deleteRemote(String id);

  Future<List<BrandWarehouseLocationRemoteRecord>> pullAll();
}

/// Implémentation "sans serveur" — utilisée tant que Firebase n'est pas
/// disponible (tests, environnements sans backend).
class NoBrandWarehouseLocationRemoteRepository
    implements BrandWarehouseLocationRemoteRepository {
  const NoBrandWarehouseLocationRemoteRepository();

  @override
  Future<void> push(BrandWarehouseLocationRemoteRecord record) async {}

  @override
  Future<void> deleteRemote(String id) async {}

  @override
  Future<List<BrandWarehouseLocationRemoteRecord>> pullAll() async => const [];
}
