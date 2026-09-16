import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location.dart';
import 'package:genesis_picking/features/warehouse_location/data/brand_warehouse_location_repository.dart';

/// Fake en mémoire de [BrandWarehouseLocationRepository] — même principe
/// que `FakeUserRepository` : pas de framework de mock, une implémentation
/// directe de l'interface abstraite.
class FakeBrandWarehouseLocationRepository
    implements BrandWarehouseLocationRepository {
  final Map<String, BrandWarehouseLocation> _locations = {};
  var _nextId = 0;

  BrandWarehouseLocation? _findByMarque(String marque) {
    final normalisee = marque.toLowerCase();
    for (final location in _locations.values) {
      if (location.marque.toLowerCase() == normalisee) return location;
    }
    return null;
  }

  @override
  Future<List<BrandWarehouseLocation>> listAll() async => _locations.values.toList();

  @override
  Future<Result<BrandWarehouseLocation>> create({
    required String marque,
    required String emplacement,
  }) async {
    if (_findByMarque(marque) != null) {
      return const Result.failure(
        ValidationException('Cette marque a déjà un emplacement.'),
      );
    }
    final id = 'loc-${_nextId++}';
    final location = BrandWarehouseLocation(
      id: id,
      marque: marque,
      emplacement: emplacement,
    );
    _locations[id] = location;
    return Result.success(location);
  }

  @override
  Future<Result<void>> update({
    required String id,
    required String marque,
    required String emplacement,
  }) async {
    final existing = _findByMarque(marque);
    if (existing != null && existing.id != id) {
      return const Result.failure(
        ValidationException('Cette marque a déjà un emplacement.'),
      );
    }
    if (!_locations.containsKey(id)) {
      return const Result.failure(ValidationException('Emplacement introuvable.'));
    }
    _locations[id] = BrandWarehouseLocation(
      id: id,
      marque: marque,
      emplacement: emplacement,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (_locations.remove(id) == null) {
      return const Result.failure(ValidationException('Emplacement introuvable.'));
    }
    return const Result.success(null);
  }

  @override
  Future<void> upsertFromRemote({
    required String id,
    required String marque,
    required String emplacement,
  }) async {
    final doublonLocal = _findByMarque(marque);
    if (doublonLocal != null && doublonLocal.id != id) {
      _locations.remove(doublonLocal.id);
    }
    _locations[id] = BrandWarehouseLocation(
      id: id,
      marque: marque,
      emplacement: emplacement,
    );
  }
}
