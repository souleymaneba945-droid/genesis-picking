import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/auth_service.dart';
import 'package:genesis_picking/features/auth/data/login_attempt_tracker.dart';

import 'fake_user_repository.dart';

void main() {
  late FakeUserRepository repository;
  late AuthService authService;

  setUp(() async {
    repository = FakeUserRepository();
    authService = AuthService(
      userRepository: repository,
      attemptTracker: LoginAttemptTracker(),
    );
    await repository.create(
      identifiant: 'prep1',
      nomAffichage: 'Amadou',
      role: UserRole.preparateur,
      motDePasse: 'MotDePasse123',
    );
  });

  group('AuthService.login', () {
    test('réussit avec les bons identifiants', () async {
      final result = await authService.login(
        identifiant: 'prep1',
        motDePasse: 'MotDePasse123',
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (session) {
          expect(session.role, UserRole.preparateur);
          expect(session.displayName, 'Amadou');
        },
        failure: (_) => fail('devrait réussir'),
      );
    });

    test('échoue avec un identifiant inconnu', () async {
      final result = await authService.login(
        identifiant: 'inconnu',
        motDePasse: 'peu importe',
      );
      expect(result.isFailure, isTrue);
    });

    test('échoue avec un mauvais mot de passe', () async {
      final result = await authService.login(
        identifiant: 'prep1',
        motDePasse: 'mauvais',
      );
      expect(result.isFailure, isTrue);
    });

    test('refuse la connexion d\'un compte désactivé', () async {
      final account = await repository.findByIdentifiant('prep1');
      await repository.setActive(userId: account!.id, actif: false);

      final result = await authService.login(
        identifiant: 'prep1',
        motDePasse: 'MotDePasse123',
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('ne devrait jamais réussir'),
        failure: (exception) {
          expect(exception, isA<SessionException>());
          expect(exception.message, contains('n\'est plus actif'));
        },
      );
    });

    test('verrouille après 3 échecs consécutifs (Processus 1)', () async {
      for (var i = 0; i < 3; i++) {
        await authService.login(identifiant: 'prep1', motDePasse: 'mauvais');
      }

      final result = await authService.login(
        identifiant: 'prep1',
        motDePasse: 'MotDePasse123', // même le bon mot de passe est bloqué
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('devrait être verrouillé'),
        failure: (exception) {
          expect(exception.message, contains('Trop de tentatives'));
        },
      );
    });

    test('une connexion réussie réinitialise le compteur d\'échecs', () async {
      await authService.login(identifiant: 'prep1', motDePasse: 'mauvais');
      await authService.login(identifiant: 'prep1', motDePasse: 'mauvais');
      final success = await authService.login(
        identifiant: 'prep1',
        motDePasse: 'MotDePasse123',
      );
      expect(success.isSuccess, isTrue);

      // Après un succès, deux nouveaux échecs ne doivent pas suffire à
      // déclencher un verrouillage (le compteur est reparti à zéro).
      await authService.login(identifiant: 'prep1', motDePasse: 'mauvais');
      final stillUsable = await authService.login(
        identifiant: 'prep1',
        motDePasse: 'mauvais',
      );
      expect(stillUsable.isFailure, isTrue);
      stillUsable.when(
        success: (_) => fail('devrait échouer'),
        failure: (exception) {
          expect(exception.message, isNot(contains('Trop de tentatives')));
        },
      );
    });
  });
}
