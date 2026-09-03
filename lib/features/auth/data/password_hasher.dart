import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe utilisateur.
///
/// Chaque compte reçoit un sel aléatoire propre ([generateSalt]), combiné
/// au mot de passe avant hachage, afin qu'un même mot de passe ne
/// produise jamais le même hash pour deux comptes différents.
///
/// PBKDF2-HMAC-SHA256, 210 000 itérations (recommandation OWASP) —
/// volontairement LENT (quelques dizaines à centaines de millisecondes
/// par vérification, négligeable pour une connexion, mais très coûteux à
/// grande échelle pour un essai systématique de mots de passe). Choisi le
/// 03/09/2026, en remplacement d'un simple SHA-256 salé : les comptes
/// (hash + sel) transitent par Firestore pour la synchronisation
/// multi-appareils (voir `SyncingUserRepository`), dont les règles
/// d'accès sont grandes ouvertes (voir `firestore.rules`) — n'importe qui
/// possédant la configuration Firebase de l'appli (non secrète, intégrée
/// à chaque .apk) peut donc lire ces hash. Un hachage volontairement lent
/// rend un essai systématique hors-ligne des mots de passe obtenus ainsi
/// des dizaines de milliers de fois plus coûteux qu'un simple SHA-256 —
/// ça ne remplace pas la vraie correction (fermer l'accès à Firestore),
/// mais réduit fortement l'impact tant que ce chantier plus lourd n'est
/// pas fait.
///
/// MIGRATION TRANSPARENTE : le format stocké commence toujours par
/// `"pbkdf2$<itérations>$"`, ce qui permet à [verify] de reconnaître un
/// compte encore au format historique (SHA-256 simple, sans ce préfixe —
/// tel que produit par l'implémentation d'origine) et de le vérifier
/// correctement quand même. [necessiteRehachage] indique alors à
/// l'appelant (voir `AuthService.login`) qu'il doit re-hacher le mot de
/// passe — qu'il vient de vérifier avec succès, donc qu'il connaît en
/// clair à cet instant précis — et l'enregistrer au nouveau format :
/// aucun compte existant n'est cassé, chacun est mis à niveau
/// automatiquement, un par un, à sa prochaine connexion réussie.
class PasswordHasher {
  PasswordHasher._();

  static const int _saltLength = 16;
  static const int _iterations = 210000;
  static const String _prefix = 'pbkdf2';

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hash({required String password, required String salt}) {
    final derive = _pbkdf2(password: password, salt: salt, iterations: _iterations);
    return '$_prefix\$$_iterations\$$derive';
  }

  static bool verify({
    required String password,
    required String salt,
    required String expectedHash,
  }) {
    if (expectedHash.startsWith('$_prefix\$')) {
      final segments = expectedHash.split(r'$');
      if (segments.length != 3) return false;
      final iterations = int.tryParse(segments[1]);
      if (iterations == null || iterations <= 0) return false;
      final derive = _pbkdf2(password: password, salt: salt, iterations: iterations);
      return _constantTimeEquals(derive, segments[2]);
    }
    // Format historique (SHA-256 simple, sans préfixe) — comptes créés
    // avant le renforcement du 03/09/2026, jamais modifiés depuis.
    final legacy = _legacySha256(password: password, salt: salt);
    return _constantTimeEquals(legacy, expectedHash);
  }

  /// `true` si [storedHash] est encore au format historique (SHA-256
  /// simple, non salé par itération) — voir la docstring de classe pour
  /// la migration transparente que ça déclenche côté [AuthService].
  static bool necessiteRehachage(String storedHash) {
    return !storedHash.startsWith('$_prefix\$');
  }

  static String _legacySha256({required String password, required String salt}) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// PBKDF2-HMAC-SHA256, un seul bloc de sortie (SHA-256 produit déjà les
  /// 256 bits voulus ici, pas besoin d'un second bloc) — implémentation
  /// directe de RFC 8018 §5.2, sans dépendance supplémentaire (le paquet
  /// `crypto`, déjà utilisé, expose tout le nécessaire via [Hmac]).
  static String _pbkdf2({
    required String password,
    required String salt,
    required int iterations,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final blocIndex = Uint8List(4)..buffer.asByteData().setUint32(0, 1, Endian.big);

    var u = Uint8List.fromList(hmac.convert([...utf8.encode(salt), ...blocIndex]).bytes);
    final resultat = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < resultat.length; j++) {
        resultat[j] ^= u[j];
      }
    }
    return base64Url.encode(resultat);
  }

  /// Comparaison en temps constant — évite qu'une différence de durée
  /// entre "les premiers octets ne correspondent pas" et "presque tout
  /// correspond" ne fuite d'information sur le hash attendu (attaque par
  /// canal auxiliaire classique sur une comparaison naïve `==`).
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
