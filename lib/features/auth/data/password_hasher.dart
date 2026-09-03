import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe utilisateur.
///
/// Chaque compte reçoit un sel aléatoire propre ([generateSalt]), combiné
/// au mot de passe avant hachage (SHA-256), afin qu'un même mot de passe
/// ne produise jamais le même hash pour deux comptes différents.
///
/// NOTE POUR L'ÉQUIPE : SHA-256 salé est un choix pragmatique pour ce
/// stade du projet (aucune dépendance native supplémentaire). Avant un
/// déploiement commercial (voir l'ambition du PRD), il est recommandé de
/// migrer vers un algorithme dédié aux mots de passe (Argon2id ou bcrypt)
/// une fois le Module 7 (Synchronisation / backend) en place — la
/// signature de [PasswordHasher] ne changerait pas, seule l'implémentation
/// interne serait remplacée.
class PasswordHasher {
  PasswordHasher._();

  static const int _saltLength = 16;

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hash({required String password, required String salt}) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static bool verify({
    required String password,
    required String salt,
    required String expectedHash,
  }) {
    return hash(password: password, salt: salt) == expectedHash;
  }
}
