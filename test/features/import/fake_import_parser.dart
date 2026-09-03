import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';

/// Faux analyseur entièrement contrôlable, pour tester `ImportEngine`
/// indépendamment de tout vrai format.
class FakeImportParser implements ImportParser {
  FakeImportParser({
    this.format = ImportFormat.pdf,
    this.result,
    this.errorToThrow,
  });

  @override
  final ImportFormat format;

  ParsedTournee? result;
  Object? errorToThrow;

  int parseCallCount = 0;

  @override
  Future<ParsedTournee> parse(
    ImportSource source, {
    void Function(int done, int total)? onProgress,
  }) async {
    parseCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return result ?? const ParsedTournee(produits: []);
  }
}
