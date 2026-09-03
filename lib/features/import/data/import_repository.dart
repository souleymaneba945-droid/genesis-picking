import 'package:genesis_picking/features/import/data/import_report.dart';

/// Contrat abstrait de persistance de l'historique des imports.
/// `ImportEngine` ne dépend que de cette interface, jamais de Drift.
abstract interface class ImportRepository {
  Future<void> recordImport(ImportReport report);

  /// Historique complet, le plus récent en premier.
  Future<List<ImportReport>> history();
}
