import 'package:drift/drift.dart';

/// Table clé/valeur générique pour les métadonnées internes de
/// l'application (ex. version du schéma appliquée, horodatage de la
/// dernière synchronisation réussie).
///
/// Ne doit JAMAIS accueillir de données métier (tournées, produits,
/// demandes coursier) : ces tables seront créées par leurs modules
/// respectifs (Module 3, 4, 5) dans `core/storage/tables/`, chacune dans
/// son propre fichier, puis déclarées dans [LocalDatabase].
class AppMetadataTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
