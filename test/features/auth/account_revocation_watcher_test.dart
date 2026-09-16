import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/auth/presentation/account_revocation_watcher.dart';

UserAccount _compte({required bool actif}) {
  return UserAccount(
    id: 'user-1',
    identifiant: 'test',
    nomAffichage: 'Test',
    role: UserRole.preparateur,
    actif: actif,
    creeLe: DateTime(2026),
  );
}

void main() {
  group(
    'shouldRevokeSession — Module 5 v2, Rubrique 3 (révocation à distance)',
    () {
      test('compte désormais inactif → doit fermer la session', () {
        expect(shouldRevokeSession(_compte(actif: false)), isTrue);
      });

      test('compte toujours actif → ne touche jamais à la session', () {
        expect(shouldRevokeSession(_compte(actif: true)), isFalse);
      });

      test(
        'compte introuvable (null, cas extrêmement rare) → jamais traité '
        'comme une révocation',
        () {
          expect(shouldRevokeSession(null), isFalse);
        },
      );
    },
  );
}
