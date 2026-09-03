import 'package:genesis_picking/core/session/user_role.dart';

/// Représentation immuable d'une session utilisateur active.
///
/// Ne contient volontairement que le strict nécessaire à la Fondation
/// (Module 1) : l'identité et le rôle. Le Module 2 (Authentification et
/// gestion des utilisateurs) y ajoutera les informations de profil.
class UserSession {
  const UserSession({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.token,
  });

  final String userId;
  final String displayName;
  final UserRole role;

  /// Jeton d'authentification, utilisé par le Module 7 (Synchronisation)
  /// pour identifier les requêtes envoyées au serveur.
  final String token;
}
