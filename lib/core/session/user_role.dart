/// Les trois rôles définis dans la Spécification Fonctionnelle et le PRD.
///
/// Un rôle ne doit jamais être déduit implicitement ailleurs dans le code
/// (ex. via une chaîne de caractères recopiée) : toujours passer par cette
/// énumération pour éviter toute divergence entre modules.
enum UserRole { administrateur, preparateur, coursier }

/// Conversion vers/depuis la représentation stockée (base locale, stockage
/// sécurisé). Centralisée ici pour qu'un seul endroit du code connaisse le
/// format de stockage exact.
extension UserRoleStorage on UserRole {
  String get storageKey => switch (this) {
    UserRole.administrateur => 'administrateur',
    UserRole.preparateur => 'preparateur',
    UserRole.coursier => 'coursier',
  };

  static UserRole fromStorageKey(String key) {
    return switch (key) {
      'administrateur' => UserRole.administrateur,
      'preparateur' => UserRole.preparateur,
      'coursier' => UserRole.coursier,
      _ => throw ArgumentError('Rôle inconnu en stockage : $key'),
    };
  }
}
