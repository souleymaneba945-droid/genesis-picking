import 'package:genesis_picking/features/import/data/import_report.dart';
import 'package:genesis_picking/features/import/data/import_repository.dart';

class FakeImportRepository implements ImportRepository {
  final List<ImportReport> _history = [];

  @override
  Future<void> recordImport(ImportReport report) async {
    _history.insert(0, report);
  }

  @override
  Future<List<ImportReport>> history() async => List.unmodifiable(_history);
}
