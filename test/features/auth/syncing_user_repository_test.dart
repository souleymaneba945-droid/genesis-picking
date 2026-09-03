import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/syncing_user_repository.dart';
import 'package:genesis_picking/features/auth/data/user_pull_sync.dart';
import 'package:genesis_picking/features/auth/data/remote/user_remote_repository.dart';

import 'fake_user_remote_repository.dart';
import 'fake_user_repository.dart';

void main() {
  late FakeUserRepository local;
  late FakeUserRemoteRepository remote;
  late SyncingUserRepository repository;

  setUp(() {
    local = FakeUserRepository();
    remote = FakeUserRemoteRepository();
    repository = SyncingUserRepository(local, remote);
  });

  group('SyncingUserRepository — transmission après écriture locale', () {
    test('un compte créé est transmis au serveur avec son hash/sel',
        () async {
      final result = await repository.create(
        identifiant: 'amadou',
        nomAffichage: 'Amadou',
        role: UserRole.preparateur,
        motDePasse: 'MotDePasse123',
      );

      expect(result.isSuccess, isTrue);
      expect(remote.pushed, hasLength(1));
      final pushed = remote.pushed.single;
      expect(pushed.identifiant, 'amadou');
      expect(pushed.role, UserRole.preparateur);
      expect(pushed.motDePasseHash, isNotEmpty);
      expect(pushed.motDePasseSel, isNotEmpty);
    });

    test('une création refusée (identifiant déjà pris) n\'est jamais '
        'transmise', () async {
      await repository.create(
        identifiant: 'amadou',
        nomAffichage: 'Amadou',
        role: UserRole.preparateur,
        motDePasse: 'MotDePasse123',
      );
      remote.pushed.clear();

      final result = await repository.create(
        identifiant: 'amadou',
        nomAffichage: 'Autre',
        role: UserRole.coursier,
        motDePasse: 'AutreMotDePasse1',
      );

      expect(result.isFailure, isTrue);
      expect(remote.pushed, isEmpty);
    });

    test('une désactivation est transmise au serveur', () async {
      final created = await repository.create(
        identifiant: 'moussa',
        nomAffichage: 'Moussa',
        role: UserRole.coursier,
        motDePasse: 'MotDePasse123',
      );
      final userId = created.when(
        success: (a) => a.id,
        failure: (_) => fail('devrait réussir'),
      );
      remote.pushed.clear();

      await repository.setActive(userId: userId, actif: false);

      expect(remote.pushed, hasLength(1));
      expect(remote.pushed.single.actif, isFalse);
    });

    test(
        'un échec réseau lors de la transmission n\'empêche pas '
        'l\'écriture locale de réussir', () async {
      remote.shouldThrow = true;

      final result = await repository.create(
        identifiant: 'fatou',
        nomAffichage: 'Fatou',
        role: UserRole.preparateur,
        motDePasse: 'MotDePasse123',
      );

      expect(result.isSuccess, isTrue);
      final compte = await repository.findByIdentifiant('fatou');
      expect(compte, isNotNull);
    });
  });

  group('SyncingUserRepository — lecture, toujours locale', () {
    test('upsertFromRemote n\'est jamais renvoyé vers le serveur '
        '(pas d\'aller-retour)', () async {
      await repository.upsertFromRemote(
        id: 'id-1',
        identifiant: 'thierno',
        nomAffichage: 'Thierno',
        role: UserRole.coursier,
        actif: true,
        motDePasseHash: 'hash',
        motDePasseSel: 'sel',
        creeLe: DateTime(2026),
      );

      expect(remote.pushed, isEmpty);
      final compte = await repository.findByIdentifiant('thierno');
      expect(compte, isNotNull);
    });
  });

  group('UserPullSync — récupération des comptes au démarrage', () {
    late UserPullSync pullSync;

    setUp(() {
      pullSync = UserPullSync(local, remote);
    });

    test('intègre localement chaque compte connu du serveur', () async {
      remote.serverRecords = [
        UserRemoteRecord(
          id: 'id-1',
          identifiant: 'amadou',
          nomAffichage: 'Amadou',
          role: UserRole.preparateur,
          actif: true,
          motDePasseHash: 'hash-1',
          motDePasseSel: 'sel-1',
          creeLe: DateTime(2026),
        ),
      ];

      await pullSync.pullAll();

      final compte = await local.findByIdentifiant('amadou');
      expect(compte, isNotNull);
      expect(compte!.role, UserRole.preparateur);
      final credentials = await local.credentialsFor('amadou');
      expect(credentials?.hash, 'hash-1');
    });

    test('un échec réseau n\'empêche jamais le démarrage — reste '
        'silencieux', () async {
      remote.shouldThrow = true;

      // Ne doit lancer aucune exception.
      await pullSync.pullAll();
    });
  });
}
