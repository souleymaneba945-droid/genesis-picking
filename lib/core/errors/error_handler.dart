import 'package:flutter/foundation.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';

/// Gestionnaire d'erreurs global de l'application.
///
/// Deux responsabilités strictement séparées :
/// 1. Capturer toute erreur non interceptée (Flutter framework ou
///    asynchrone) pour qu'aucune ne soit jamais silencieuse.
/// 2. Traduire une [AppException] technique en message utilisateur court,
///    professionnel et compréhensible (voir Processus 10 — Gestion des
///    erreurs), conformément aux textes déjà validés dans le PRD.
class ErrorHandler {
  ErrorHandler._();

  /// À appeler une seule fois, au tout début de `main()`.
  static void initializeGlobalCapture() {
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        'Erreur Flutter non interceptée',
        tag: 'ErrorHandler',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.error(
        'Erreur asynchrone non interceptée',
        tag: 'ErrorHandler',
        error: error,
        stackTrace: stack,
      );
      // On indique que l'erreur a été traitée : conformément au principe
      // "vos données sont conservées" (Processus 10), on ne laisse jamais
      // planter l'application sur une erreur imprévue.
      return true;
    };
  }

  /// Traduit une [AppException] en message affichable à l'utilisateur.
  ///
  /// Les textes correspondent exactement à ceux validés dans le PRD
  /// (chapitre 9 — Messages utilisateur) et le Processus 10.
  static String userMessageFor(AppException exception) {
    return switch (exception) {
      NetworkException() =>
        'Pas de connexion. Votre travail est enregistré et sera transmis '
            'automatiquement.',
      ValidationException() => exception.message,
      StorageException() =>
        'Une erreur est survenue. Vos données sont conservées. Réessayez.',
      SessionException() => exception.message,
      UnknownException() =>
        'Une erreur est survenue. Vos données sont conservées. Réessayez.',
    };
  }
}
