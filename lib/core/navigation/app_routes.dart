/// Noms de routes centralisés.
///
/// Aucune chaîne de caractères de route ne doit être écrite directement
/// dans un écran : toujours passer par cette classe, pour qu'un
/// renommage de route se fasse à un seul endroit.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/connexion';

  // Racines par rôle — les écrans réels seront construits par les modules
  // métier (Module 2 et suivants). Ce sont ici des points d'ancrage de
  // navigation, pas des fonctionnalités.
  static const String homeAdministrateur = '/admin';
  static const String homePreparateur = '/preparateur';
  static const String homeCoursier = '/coursier';
}
