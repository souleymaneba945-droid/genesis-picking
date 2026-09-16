import 'package:drift/drift.dart';

/// Table de correspondance marque → emplacement dans l'entrepôt (Module 5
/// v2, Rubrique 2).
///
/// STRICTEMENT INDÉPENDANTE de `TourProductLinesTable.emplacement` — cette
/// dernière est l'emplacement de PICKING (fourni par le PDF, pour le
/// préparateur) ; cette table-ci est l'emplacement PHYSIQUE dans
/// l'entrepôt (saisi par l'administrateur, pour le coursier). Les deux ne
/// doivent jamais être mélangés, ni en base, ni à l'écran — voir
/// `MODULE_5_V2.md`, Rubrique 2.
///
/// Granularité par MARQUE uniquement, jamais par produit individuel —
/// [marque] doit être unique (vérifié en amont dans le repository,
/// insensible à la casse, même principe que `identifiant` sur
/// `UsersTable`).
class BrandWarehouseLocationsTable extends Table {
  TextColumn get id => text()();

  TextColumn get marque => text()();

  /// Texte libre, sans structure imposée (même principe que l'emplacement
  /// picking existant) — ex. "Zone A - Étagère 3".
  TextColumn get emplacement => text()();

  @override
  Set<Column> get primaryKey => {id};
}
