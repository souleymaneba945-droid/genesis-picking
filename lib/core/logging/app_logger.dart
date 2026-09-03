import 'package:logger/logger.dart';

/// Niveaux de log utilisés dans tout le projet.
///
/// Volontairement restreint à ce qui a un sens métier ou technique concret
/// (voir Processus 11 — Journal des événements de la Spécification
/// Fonctionnelle) : un `event` correspond à une action métier tracée
/// (connexion, validation de produit, etc.), les autres niveaux sont
/// purement techniques.
enum AppLogLevel { debug, info, event, warning, error }

/// Point d'accès unique à la journalisation.
///
/// Aucune partie du code applicatif ne doit utiliser `print()` directement
/// (voir `analysis_options.yaml`, règle `avoid_print`) : tout passe par
/// [AppLogger], pour permettre plus tard de rediriger les logs vers un
/// fichier local ou un service distant sans toucher au reste du code.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void debug(String message, {String? tag}) {
    _logger.d(_format(message, tag));
  }

  static void info(String message, {String? tag}) {
    _logger.i(_format(message, tag));
  }

  /// À utiliser pour tout événement métier qui doit alimenter le futur
  /// journal des événements applicatif (Processus 11).
  static void event(String message, {String? tag}) {
    _logger.i('[EVENT] ${_format(message, tag)}');
  }

  static void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.w(_format(message, tag), error: error, stackTrace: stackTrace);
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.e(_format(message, tag), error: error, stackTrace: stackTrace);
  }

  static String _format(String message, String? tag) {
    return tag != null ? '[$tag] $message' : message;
  }
}
