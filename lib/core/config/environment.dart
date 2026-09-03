/// Environnements possibles de l'application.
///
/// Utilisé pour distinguer le comportement (logs plus verbeux en dev,
/// endpoints de synchronisation différents une fois le Module 7 construit,
/// etc.) sans jamais dupliquer le code entre environnements.
enum Environment { dev, staging, prod }

/// Point d'accès unique à l'environnement courant.
///
/// [Environment] est fixé au démarrage de l'application (voir `main.dart`)
/// et ne doit jamais être modifié en cours d'exécution.
class EnvironmentConfig {
  const EnvironmentConfig._({
    required this.environment,
    required this.enableVerboseLogging,
  });

  final Environment environment;
  final bool enableVerboseLogging;

  static const EnvironmentConfig dev = EnvironmentConfig._(
    environment: Environment.dev,
    enableVerboseLogging: true,
  );

  static const EnvironmentConfig staging = EnvironmentConfig._(
    environment: Environment.staging,
    enableVerboseLogging: true,
  );

  static const EnvironmentConfig prod = EnvironmentConfig._(
    environment: Environment.prod,
    enableVerboseLogging: false,
  );

  bool get isProd => environment == Environment.prod;
}
