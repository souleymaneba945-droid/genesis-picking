import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/auth/data/login_attempt_tracker.dart';

void main() {
  group('LoginAttemptTracker', () {
    test('aucun verrouillage tant que le seuil n\'est pas atteint', () {
      final tracker = LoginAttemptTracker();
      tracker.recordFailure('prep1');
      tracker.recordFailure('prep1');
      expect(tracker.lockoutRemaining('prep1'), isNull);
    });

    test('verrouille après le nombre de tentatives configuré', () {
      final tracker = LoginAttemptTracker();
      tracker.recordFailure('prep1');
      tracker.recordFailure('prep1');
      tracker.recordFailure('prep1');
      expect(tracker.lockoutRemaining('prep1'), isNotNull);
    });

    test('reset() supprime le verrouillage', () {
      final tracker = LoginAttemptTracker();
      tracker.recordFailure('prep1');
      tracker.recordFailure('prep1');
      tracker.recordFailure('prep1');
      tracker.reset('prep1');
      expect(tracker.lockoutRemaining('prep1'), isNull);
    });

    test('les compteurs sont indépendants par identifiant', () {
      final tracker = LoginAttemptTracker();
      tracker.recordFailure('prep1');
      tracker.recordFailure('prep1');
      tracker.recordFailure('prep1');
      expect(tracker.lockoutRemaining('prep1'), isNotNull);
      expect(tracker.lockoutRemaining('coursier1'), isNull);
    });
  });
}
