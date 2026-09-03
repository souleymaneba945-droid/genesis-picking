import 'package:drift/drift.dart';
import 'package:genesis_picking/core/activity/activity_level.dart';

/// Historique d'activité — journal humainement lisible des actions de
/// picking et de traitement coursier, PAR utilisateur (préparateur ou
/// coursier — même table, filtrée par [userId]).
///
/// Ne remplace ni ne duplique aucune donnée métier :
/// `TourProductLinesTable`/`PickingProductStatusesTable` et
/// `CourierRequestsTable` restent les seules sources de vérité pour ce
/// qui a réellement été fait. Ce journal n'est qu'une trace affichable et
/// purgeable à l'écran — le purger n'efface jamais une tournée, un
/// produit ni une demande, seulement son propre historique.
class ActivityLogTable extends Table {
  TextColumn get id => text()();

  /// Compte à qui appartient cette entrée (préparateur ou coursier).
  TextColumn get userId => text()();

  TextColumn get level => textEnum<ActivityLevel>()();
  TextColumn get message => text()();
  DateTimeColumn get dateHeure => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
