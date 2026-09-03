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
  });
}
