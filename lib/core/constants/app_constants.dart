/// Constantes globales, indépendantes de tout module métier.
///
/// Ne jamais mettre ici de constantes propres à un module (ex. picking,
/// coursiers) : elles doivent vivre dans le module concerné, une fois créé.
class AppConstants {
  AppConstants._();

  static const String appName = 'GENESIS PICKING';

  /// Version affichée à l'écran Paramètres. À synchroniser manuellement
  /// avec `pubspec.yaml` (aucune dépendance supplémentaire ajoutée
  /// uniquement pour la lire à l'exécution).
  static const String appVersion = '0.1.0';

  /// Nom du fichier de base de données locale (Drift).
  static const String databaseFileName = 'genesis_picking';

  /// Clés utilisées pour le stockage sécurisé de la session.
  static const String secureStorageKeyToken = 'session_token';
  static const String secureStorageKeyRole = 'session_role';
  static const String secureStorageKeyUserId = 'session_user_id';

  /// Délai avant qu'une tentative de connexion échouée soit débloquée
  /// (voir Spécification Fonctionnelle, règles de connexion).
  static const Duration loginLockoutDuration = Duration(seconds: 60);
  static const int maxLoginAttempts = 3;

  /// Langue par défaut (V1 : uniquement le français, mais le système
  /// d'internationalisation est prêt à en accueillir d'autres).
  static const String defaultLocaleCode = 'fr';
}
