import 'package:genesis_picking/core/config/environment.dart';

/// Configuration globale de l'application.
///
/// Regroupe tout ce qui doit être connu au démarrage et rester accessible
/// partout, sans dépendre d'un widget particulier (contrairement à un
/// provider Riverpod classique). Volontairement minimal en Module 1 :
/// les modules suivants y ajouteront leurs propres réglages (ex. adresse
/// du serveur de synchronisation au Module 7), jamais leur logique.
class AppConfig {
  AppConfig._({required this.environment});

  static AppConfig? _instance;

  final EnvironmentConfig environment;

  /// Doit être appelé une seule fois, au tout début de `main()`.
  static void initialize({required EnvironmentConfig environment}) {
    _instance = AppConfig._(environment: environment);
  }

  static AppConfig get instance {
    final config = _instance;
    if (config == null) {
      throw StateError(
        'AppConfig.initialize() doit être appelé avant toute utilisation.',
      );
    }
    return config;
  }
}
