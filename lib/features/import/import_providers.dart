import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/features/import/data/drift_import_repository.dart';
import 'package:genesis_picking/features/import/data/import_repository.dart';
import 'package:genesis_picking/features/import/data/parsers/csv_parser.dart';
import 'package:genesis_picking/features/import/data/parsers/excel_parser.dart';
import 'package:genesis_picking/features/import/data/parsers/json_parser.dart';
import 'package:genesis_picking/features/import/data/parsers/pdf_parser.dart';
import 'package:genesis_picking/features/import/data/parsers/pdf_text_extractor.dart';
import 'package:genesis_picking/features/import/domain/import_engine.dart';
import 'package:genesis_picking/features/import/domain/import_validator.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return DriftImportRepository(ref.watch(localDatabaseProvider));
});

final importValidatorProvider = Provider<ImportValidator>((ref) {
  return ImportValidator();
});

/// Registre des analyseurs disponibles (Directive : architecture
/// adaptable). Ajouter un format = ajouter une ligne ici.
final importEngineProvider = Provider<ImportEngine>((ref) {
  return ImportEngine(
    parsers: [
      PdfParser(textExtractor: SyncfusionPdfTextExtractor()),
      CsvParser(),
      ExcelParser(),
      JsonParser(),
    ],
    validator: ref.watch(importValidatorProvider),
    tourRepository: ref.watch(tourRepositoryProvider),
    importRepository: ref.watch(importRepositoryProvider),
    tourRemoteSink: ref.watch(tourRemoteSinkProvider),
  );
});
