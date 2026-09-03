import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/auth_service.dart';
import 'package:genesis_picking/features/auth/data/login_attempt_tracker.dart';
import 'package:genesis_picking/features/auth/data/password_hasher.dart';

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

  group('AuthService.login — renforcement transparent du hachage', () {
    // Reproduit un compte tel qu'il existerait AVANT le renforcement du
    // 03/09/2026 (hash SHA-256 simple, sans préfixe) — via
    // `upsertFromRemote`, qui écrit le hash/sel tels quels, exactement
    // comme le ferait une synchronisation Firestore d'un compte ancien.
    Future<void> seedCompteAncienFormat({
      required String identifiant,
      required String motDePasse,
    }) async {
      final salt = PasswordHasher.generateSalt();
      final legacyHash =
          sha256.convert(utf8.encode('$salt:$motDePasse')).toString();
      await repository.upsertFromRemote(
        id: identifiant,
        identifiant: identifiant,
        nomAffichage: 'Ancien Compte',
        role: UserRole.preparateur,
        actif: true,
        motDePasseHash: legacyHash,
        motDePasseSel: salt,
        creeLe: DateTime.now(),
      );
    }

    test('une connexion réussie sur un compte ancien format renforce son hash',
        () async {
      await seedCompteAncienFormat(
        identifiant: 'ancien1',
        motDePasse: 'MotDePasse123',
      );
      final avant = await repository.credentialsFor('ancien1');
      expect(PasswordHasher.necessiteRehachage(avant!.hash), isTrue);

      final result = await authService.login(
        identifiant: 'ancien1',
        motDePasse: 'MotDePasse123',
      );
      expect(result.isSuccess, isTrue);

      final apres = await repository.credentialsFor('ancien1');
      expect(PasswordHasher.necessiteRehachage(apres!.hash), isFalse);
    });

    test('le compte renforcé reste utilisable à la connexion suivante',
        () async {
      await seedCompteAncienFormat(
        identifiant: 'ancien2',
        motDePasse: 'MotDePasse123',
      );
      await authService.login(identifiant: 'ancien2', motDePasse: 'MotDePasse123');

      final second = await authService.login(
        identifiant: 'ancien2',
        motDePasse: 'MotDePasse123',
      );
      expect(second.isSuccess, isTrue);
    });

    test('un compte déjà au format actuel n\'est jamais re-haché inutilement',
        () async {
      // 'prep1' (créé dans setUp via .create()) est déjà au format actuel.
      final avant = await repository.credentialsFor('prep1');

      await authService.login(identifiant: 'prep1', motDePasse: 'MotDePasse123');

      final apres = await repository.credentialsFor('prep1');
      expect(apres!.hash, avant!.hash);
      expect(apres.sel, avant.sel);
    });
  });
}
