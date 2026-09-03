import 'package:drift/drift.dart';

/// Journal des exécutions de synchronisation (Directive Module 6,
/// "Journal") : chaque exécution de [SyncService.synchronizeNow] écrit
/// une ligne ici, avec début, fin, durée (calculée), nombre d'éléments
/// traités et erreurs rencontrées.
class SyncRunLogsTable extends Table {
  TextColumn get id => text()();

  DateTimeColumn get startedAt => dateTime()();

  /// Nulle tant que l'exécution est en cours.
  DateTimeColumn get finishedAt => dateTime().nullable()();

  IntColumn get itemsProcessed => integer().withDefault(const Constant(0))();
  IntColumn get itemsSucceeded => integer().withDefault(const Constant(0))();
  IntColumn get itemsFailed => integer().withDefault(const Constant(0))();

  /// Résumé des erreurs rencontrées (messages concaténés, tronqué) — un
  /// journal de diagnostic, pas une donnée structurée à ré-exploiter.
  TextColumn get errorSummary => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
