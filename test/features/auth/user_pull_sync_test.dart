import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/remote/user_remote_repository.dart';
import 'package:genesis_picking/features/auth/data/user_pull_sync.dart';

import 'fake_user_remote_repository.dart';
import 'fake_user_repository.dart';

// Note : le cas "un compte connu du serveur est intégré localement" et
// "une panne réseau au démarrage n'empêche jamais l'appli de démarrer"
// sont déjà couverts par `syncing_user_repository_test.dart` (groupe
// "UserPullSync — récupération des comptes au démarrage") — ce fichier
// se concentre sur le cas qui manquait : l'isolation d'un compte en
// échec au milieu du lot (le bug réel observé sur le terrain).

UserRemoteRecord _compte(String identifiant) {
  return UserRemoteRecord(
    id: 'id-$identifiant',
    identifiant: identifiant,
    nomAffichage: identifiant.toUpperCase(),
    role: UserRole.preparateur,
    actif: true,
    motDePasseHash: 'hash',
    motDePasseSel: 'sel',
    creeLe: DateTime(2026, 1, 1),
  );
}

void main() {
  test(
      'un compte en échec (doublon local) n\'empêche pas les autres '
      'd\'être synchronisés — c\'était le bug réel observé sur le '
      'terrain (un doublon bloquait tous les comptes suivants dans la '
      'même récupération)', () async {
    final local = FakeUserRepository();
    final remote = FakeUserRemoteRepository();
    final sync = UserPullSync(local, remote);

    remote.serverRecords = [
      _compte('amadou'),
      _compte('thierno'),
      _compte('fatou'),
    ];
    local.echecUpsertPour.add('thierno');

    await sync.pullAll();

    final identifiants = (await local.listAll()).map((c) => c.identifiant).toSet();
    expect(identifiants, contains('amadou'));
    expect(identifiants, contains('fatou'));
    expect(identifiants, isNot(contains('thierno')));
  });
}
