import 'package:drift/drift.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/features/import/data/import_report.dart';
import 'package:genesis_picking/features/import/data/import_repository.dart';
import 'package:uuid/uuid.dart';

class DriftImportRepository implements ImportRepository {
  DriftImportRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  @override
  Future<void> recordImport(ImportReport report) async {
    final erreursEtAvertissements = report.issues
        .map((i) => '[${i.severity.name}] ${i.message}')
        .toList();

    await _database
        .into(_database.importHistoryTable)
        .insert(
          ImportHistoryTableCompanion.insert(
            id: _uuid.v4(),
            date: report.date,
            importePar: report.importePar,
            dureeMs: report.duree.inMilliseconds,
            format: report.format,
            succes: report.succes,
            numeroTournee: Value(report.numeroTournee),
            tourId: Value(report.tourId),
            nombreProduits: Value(report.nombreProduits),
            erreurs: Value(
              erreursEtAvertissements.isEmpty
                  ? null
                  : erreursEtAvertissements.take(50).join(' | '),
            ),
          ),
        );
  }

  @override
  Future<List<ImportReport>> history() async {
    final rows =
        await (_database.select(_database.importHistoryTable)
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
            .get();

    return rows
        .map(
          (row) => ImportReport(
            succes: row.succes,
            format: row.format,
            date: row.date,
            importePar: row.importePar,
            duree: Duration(milliseconds: row.dureeMs),
            nombreProduits: row.nombreProduits,
            issues: const [], // Détail non ré-hydraté depuis le résumé texte.
            tourId: row.tourId,
            numeroTournee: row.numeroTournee,
          ),
        )
        .toList();
  }
}
