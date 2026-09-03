import 'package:drift/drift.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';

/// Historique des imports (Directive : "Chaque import doit enregistrer
/// date, utilisateur, durée, format, résultat, erreurs").
class ImportHistoryTable extends Table {
  TextColumn get id => text()();

  DateTimeColumn get date => dateTime()();
  TextColumn get importePar => text()();
  IntColumn get dureeMs => integer()();
  TextColumn get format => textEnum<ImportFormat>()();
  BoolColumn get succes => boolean()();
  TextColumn get numeroTournee => text().nullable()();
  TextColumn get tourId => text().nullable()();
  IntColumn get nombreProduits => integer().withDefault(const Constant(0))();

  /// Erreurs et avertissements concaténés (journal de diagnostic, pas une
  /// donnée structurée à ré-exploiter — même principe que
  /// `SyncRunLogsTable.errorSummary`, Module 6).
  TextColumn get erreurs => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
