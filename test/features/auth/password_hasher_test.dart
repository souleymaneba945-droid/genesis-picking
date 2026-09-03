import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/auth/data/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('deux sels générés sont différents', () {
      final saltA = PasswordHasher.generateSalt();
      final saltB = PasswordHasher.generateSalt();
      expect(saltA, isNot(equals(saltB)));
    });

    test('verify réussit avec le bon mot de passe et le bon sel', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash(password: 'MotDePasse123', salt: salt);

      expect(
        PasswordHasher.verify(
          password: 'MotDePasse123',
          salt: salt,
          expectedHash: hash,
        ),
        isTrue,
      );
    });

    test('verify échoue avec un mauvais mot de passe', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash(password: 'MotDePasse123', salt: salt);

      expect(
        PasswordHasher.verify(
          password: 'AutreMotDePasse',
          salt: salt,
          expectedHash: hash,
        ),
        isFalse,
      );
    });

    test('le même mot de passe avec deux sels différents produit des hash différents', () {
      final saltA = PasswordHasher.generateSalt();
      final saltB = PasswordHasher.generateSalt();

      final hashA = PasswordHasher.hash(password: 'MotDePasse123', salt: saltA);
      final hashB = PasswordHasher.hash(password: 'MotDePasse123', salt: saltB);

      expect(hashA, isNot(equals(hashB)));
    });

    test('un hash actuel n\'a pas besoin d\'être re-haché', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash(password: 'MotDePasse123', salt: salt);

      expect(PasswordHasher.necessiteRehachage(hash), isFalse);
    });
  });

  group('PasswordHasher — compatibilité avec l\'ancien format (migration)', () {
    // Reproduit EXACTEMENT l'ancienne implémentation (SHA-256 simple,
    // sans préfixe) — un compte créé avant le renforcement du 03/09/2026
    // a un hash stocké sous cette forme, jamais modifié depuis.
    String legacyHash({required String password, required String salt}) {
      final bytes = utf8.encode('$salt:$password');
      return sha256.convert(bytes).toString();
    }

    test('verify reconnaît et valide un hash au format historique', () {
      final salt = PasswordHasher.generateSalt();
      final hash = legacyHash(password: 'MotDePasse123', salt: salt);

      expect(
        PasswordHasher.verify(
          password: 'MotDePasse123',
          salt: salt,
          expectedHash: hash,
        ),
        isTrue,
      );
    });

    test('verify rejette un mauvais mot de passe même au format historique', () {
      final salt = PasswordHasher.generateSalt();
      final hash = legacyHash(password: 'MotDePasse123', salt: salt);

      expect(
        PasswordHasher.verify(
          password: 'AutreMotDePasse',
          salt: salt,
          expectedHash: hash,
        ),
        isFalse,
      );
    });

    test('necessiteRehachage détecte un hash au format historique', () {
      final salt = PasswordHasher.generateSalt();
      final hash = legacyHash(password: 'MotDePasse123', salt: salt);

      expect(PasswordHasher.necessiteRehachage(hash), isTrue);
    });
  });
}
