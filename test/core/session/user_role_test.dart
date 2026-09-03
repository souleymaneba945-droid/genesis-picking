import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/session/user_role.dart';

void main() {
  group('UserRoleStorage', () {
    test('storageKey puis fromStorageKey redonne le même rôle', () {
      for (final role in UserRole.values) {
        final key = role.storageKey;
        final restored = UserRoleStorage.fromStorageKey(key);
        expect(restored, role);
      }
    });

    test('fromStorageKey lève une erreur explicite sur une clé inconnue', () {
      expect(
        () => UserRoleStorage.fromStorageKey('role_inexistant'),
        throwsArgumentError,
      );
    });
  });
}
