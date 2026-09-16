/// Une correspondance marque → emplacement entrepôt (Module 5 v2, Rubrique 2).
class BrandWarehouseLocation {
  const BrandWarehouseLocation({
    required this.id,
    required this.marque,
    required this.emplacement,
  });

  final String id;
  final String marque;
  final String emplacement;
}
