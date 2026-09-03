import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_report.dart';
import 'package:genesis_picking/features/import/data/import_repository.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';
import 'package:genesis_picking/features/import/domain/import_validator.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_sink.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_repository.dart';

/// Moteur d'import — indépendant du format (Directive : "Créer un moteur
/// d'import adaptable").
///
/// Ne contient AUCUNE logique propre à un format : il délègue entièrement
/// l'extraction à l'[ImportParser] correspondant (voir `data/parsers/`),
/// enregistré dans [_parsers]. Ajouter un format = ajouter une entrée à
/// ce registre, sans toucher à une seule ligne de cette classe.
///
/// Persiste directement via `TourRepository` (Module 3, inchangé) :
/// l'Administrateur important une picking list a déjà, par définition,
/// tout le contenu de la tournée — elle est donc créée directement à
/// l'état "Téléchargée", sans étape intermédiaire "Disponible" (voir
/// MODULE_IMPORT.md pour la justification complète).
class ImportEngine {
  ImportEngine({
    required List<ImportParser> parsers,
    required ImportValidator validator,
    required TourRepository tourRepository,
    required ImportRepository importRepository,
    TourRemoteSink tourRemoteSink = const NoTourRemoteSink(),
  }) : _validator = validator,
       _tourRepository = tourRepository,
       _importRepository = importRepository,
       _tourRemoteSink = tourRemoteSink,
       _parsers = {for (final parser in parsers) parser.format: parser};

  final Map<ImportFormat, ImportParser> _parsers;
  final ImportValidator _validator;
  final TourRepository _tourRepository;
  final ImportRepository _importRepository;

  /// Transmission best-effort vers le serveur central (voir
  /// `tour_remote_sink.dart`) — permet à la même tournée importée ici
  /// d'être téléchargeable depuis les autres appareils du même compte
  /// préparateur. `NoTourRemoteSink` par défaut : cette dépendance reste
  /// optionnelle pour tout appelant qui n'a pas encore Firebase en main
  /// (tests, environnements sans backend).
  final TourRemoteSink _tourRemoteSink;

  /// Importe une picking list (Directive : flux complet — parsing,
  /// validation, persistance, historique, jamais de crash).
  ///
  /// [onProgress], si fourni, est transmis tel quel au [ImportParser]
  /// correspondant (voir [ImportParser.parse]) — ce moteur ne connaît
  /// aucune règle propre à un format, y compris pour la progression.
  Future<ImportReport> import({
    required ImportFormat format,
    required ImportSource source,
    required String preparateurId,
    required String importedByUserId,
    void Function(int done, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final date = DateTime.now();

    final parser = _parsers[format];
    if (parser == null) {
      return _finish(
        ImportReport(
          succes: false,
          format: format,
          date: date,
          importePar: importedByUserId,
          duree: stopwatch.elapsed,
          nombreProduits: 0,
          issues: [
            ImportIssue(
              severity: ImportIssueSeverity.erreur,
              message: 'Format "${format.libelle}" non pris en charge.',
            ),
          ],
        ),
      );
    }

    // "Ne jamais planter" (Directive) : toute erreur de structure du
    // parser est capturée ici, jamais laissée remonter à l'interface.
    final ParsedTournee parsed;
    try {
      parsed = await parser.parse(source, onProgress: onProgress);
    } on ImportStructureException catch (error) {
      return _finish(
        ImportReport(
          succes: false,
          format: format,
          date: date,
          importePar: importedByUserId,
          duree: stopwatch.elapsed,
          nombreProduits: 0,
          issues: [
            ImportIssue(
              severity: ImportIssueSeverity.erreur,
              message: error.message,
            ),
          ],
        ),
      );
    } catch (error) {
      // Filet de sécurité ultime : même une erreur totalement imprévue
      // ne doit jamais planter l'application.
      AppLogger.error(
        'Erreur inattendue pendant l\'analyse de la source',
        tag: 'ImportEngine',
        error: error,
      );
      return _finish(
        ImportReport(
          succes: false,
          format: format,
          date: date,
          importePar: importedByUserId,
          duree: stopwatch.elapsed,
          nombreProduits: 0,
          issues: const [
            ImportIssue(
              severity: ImportIssueSeverity.erreur,
              message: 'Erreur inattendue pendant l\'analyse du fichier.',
            ),
          ],
        ),
      );
    }

    final issues = _validator.validate(parsed);
    final bloquant = issues.any((i) => i.estBloquant);

    if (bloquant) {
      return _finish(
        ImportReport(
          succes: false,
          format: format,
          date: date,
          importePar: importedByUserId,
          duree: stopwatch.elapsed,
          nombreProduits: parsed.produits.length,
          issues: issues,
          numeroTournee: parsed.numeroTournee,
        ),
      );
    }

    // Reprise / doublons (Directive) : l'identifiant de la tournée est
    // dérivé de façon déterministe de son numéro. Réimporter le même
    // fichier (après une interruption, ou par erreur) retombe donc
    // systématiquement sur le même identifiant : `saveDownloadedTour`
    // (Module 3, déjà atomique et idempotent) détecte alors que la
    // tournée existe déjà et ne duplique rien.
    final tourId = _deterministicTourId(parsed.numeroTournee!);
    final existing = await _tourRepository.findById(tourId);
    final dejaImportee = existing?.estTeleChargeeLocalement ?? false;

    // `bloquant` est faux ici, donc ImportValidator garantit que
    // nom/quantiteDemandee ne sont nuls sur aucun produit. L'emplacement,
    // lui, n'est plus jamais bloquant (donnée réellement absente sur une
    // partie des produits côté ERP) : une chaîne vide le remplace sans
    // crasher, plutôt qu'un force-unwrap sur une valeur potentiellement
    // nulle.
    final produits = parsed.produits
        .map(
          (p) => TourProductPayload(
            ordre: p.ligneSource,
            nom: p.nom!,
            quantiteDemandee: p.quantiteDemandee!,
            emplacement: p.emplacement ?? '',
            description: p.description,
            imageUrl: p.imageUrl,
          ),
        )
        .toList();

    await _tourRepository.saveDownloadedTour(
      tourId: tourId,
      numeroTournee: parsed.numeroTournee!,
      preparateurId: preparateurId,
      produits: produits,
    );

    // Transmission au serveur central APRÈS l'écriture locale, jamais
    // avant : la donnée locale (déjà écrite juste au-dessus) reste
    // acquise même si cet appel échoue (pas de réseau, par exemple) — un
    // import ne doit jamais échouer à cause d'un problème de
    // synchronisation, conformément au principe Offline First. Délai
    // maximum en plus des délais internes à `_tourRemoteSink` : filet de
    // sécurité final pour qu'un souci Firebase imprévu ne bloque jamais
    // l'écran d'import indéfiniment.
    try {
      await _tourRemoteSink
          .pushImportedTour(
            tourId: tourId,
            numeroTournee: parsed.numeroTournee!,
            preparateurId: preparateurId,
            produits: produits,
          )
          .timeout(const Duration(seconds: 45));
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Tournée importée localement mais pas encore transmise au '
        'serveur (sera à refaire manuellement ou au prochain import) : '
        '$tourId',
        tag: 'ImportEngine',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return _finish(
      ImportReport(
        succes: true,
        format: format,
        date: date,
        importePar: importedByUserId,
        duree: stopwatch.elapsed,
        nombreProduits: produits.length,
        issues: issues, // Avertissements éventuels (ex. images absentes).
        tourId: tourId,
        numeroTournee: parsed.numeroTournee,
        dejaImportee: dejaImportee,
      ),
    );
  }

  Future<ImportReport> _finish(ImportReport report) async {
    await _importRepository.recordImport(report);
    AppLogger.event(
      'Import ${report.succes ? 'réussi' : 'échoué'} '
      '(${report.format.libelle}, ${report.nombreProduits} produits, '
      '${report.duree.inMilliseconds} ms)',
      tag: 'ImportEngine',
    );
    return report;
  }

  String _deterministicTourId(String numeroTournee) {
    final normalise = numeroTournee
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'import-$normalise';
  }
}
