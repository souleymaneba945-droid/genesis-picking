import 'package:drift/drift.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';

/// État de collecte d'une ligne produit — table COMPAGNE de
/// `TourProductLinesTable` (Module 3), en relation un-à-un via
/// [productLineId].
///
/// Choix délibéré : une table séparée plutôt que d'ajouter des colonnes
/// directement à `TourProductLinesTable`. Cela évite de modifier le
/// fichier de table du Module 3 (qui contient déjà cet avertissement) et
/// garde une séparation nette entre "donnée brute fournie par le
/// logiciel de gestion" (Module 3) et "état de collecte propre à
/// l'application" (ce module).
class PickingProductStatusesTable extends Table {
  /// Même valeur que `TourProductLinesTable.id` — relation un-à-un.
  TextColumn get productLineId => text()();

  TextColumn get etat => textEnum<ProductState>()();

  /// Rempli uniquement pour [ProductState.collecte] et
  /// [ProductState.partiellementCollecte].
  IntColumn get quantiteCollectee => integer().nullable()();

  DateTimeColumn get miseAJourLe => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {productLineId};
}
