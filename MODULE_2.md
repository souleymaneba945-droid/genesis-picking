# GENESIS PICKING — Module 2 : Authentification et gestion des utilisateurs

Ce module s'appuie sur le socle posé au Module 1 sans le modifier, à l'exception de
deux ajouts strictement nécessaires : la table `UsersTable` dans la base locale
(schéma passé de la version 1 à 2, avec migration), et le remplacement de l'écran de
connexion provisoire par l'écran réel.

---

## 1. Ce que ce module ajoute à l'arborescence

```
lib/
├── core/
│   └── storage/
│       ├── local_database.dart        [MODIFIÉ] schéma v2 + UsersTable déclarée
│       └── tables/
│           └── users_table.dart       [NOUVEAU] table des comptes
│
├── features/
│   ├── auth/
│   │   ├── auth_providers.dart            # Providers Riverpod du module
│   │   ├── data/
│   │   │   ├── auth_service.dart          # Processus 1 : logique de connexion
│   │   │   ├── database_seeder.dart       # Bootstrap du compte admin initial
│   │   │   ├── drift_user_repository.dart # Implémentation Drift de UserRepository
│   │   │   ├── login_attempt_tracker.dart # Verrouillage après 3 échecs (Processus 1)
│   │   │   ├── password_hasher.dart       # Hachage salé des mots de passe
│   │   │   ├── user_account.dart          # Modèle de compte (indépendant de Drift)
│   │   │   └── user_repository.dart       # Interface abstraite
│   │   └── presentation/
│   │       └── login_screen.dart          # Écran 4.1 du Cahier des charges
│   │
│   ├── login_placeholder/                 [SUPPRIMÉ] remplacé par features/auth
│   │
│   ├── home_placeholder/
│   │   └── role_home_placeholder_screen.dart  [MODIFIÉ] accueil Admin donne
│   │                                            désormais accès à la gestion
│   │                                            des comptes (le reste du
│   │                                            tableau de bord reste
│   │                                            provisoire jusqu'au Module 8)
│   │
│   └── user_management/
│       └── presentation/
│           ├── user_management_screen.dart   # Écran 4.14 : liste + actions
│           ├── create_user_screen.dart        # Création de compte
│           └── reset_password_dialog.dart     # Réinitialisation de mot de passe
│
└── features/splash/splash_screen.dart      [MODIFIÉ] ouvre la base locale et
                                              amorce le compte admin par défaut
                                              avant de restaurer la session

test/
└── features/auth/
    ├── password_hasher_test.dart
    ├── login_attempt_tracker_test.dart
    ├── auth_service_test.dart
    └── fake_user_repository.dart   # Dépôt en mémoire, utilisé uniquement en test
```

---

## 2. Justification des choix

### Séparation stricte `AuthService` / `SessionManager`
`AuthService` (Module 2) vérifie les identifiants et détermine le résultat de la
connexion ; `SessionManager` (Module 1, inchangé) persiste la session déjà validée.
Aucun des deux fichiers n'a eu à être réécrit pour que l'autre existe — c'est la
preuve concrète que la modularité posée au Module 1 fonctionne : un module
consomme le socle, il ne le modifie pas.

### `UserRepository` comme interface, `DriftUserRepository` comme seule implémentation réelle
Même principe que `LocalStorageService` au Module 1 : `AuthService` et les écrans de
gestion des comptes ne connaissent que l'interface. Cela a permis d'écrire
`FakeUserRepository` (en mémoire) pour tester `AuthService` sans dépendre de Drift ni
d'un environnement Flutter complet — voir section 4.

### Hachage des mots de passe : SHA-256 salé, avec limite assumée
Un sel aléatoire propre à chaque compte est stocké à côté du hash, pour qu'un même
mot de passe ne produise jamais le même hash entre deux comptes. Ce choix est
documenté comme un compromis pragmatique dans `password_hasher.dart` lui-même :
avant toute mise en production commerciale (ambition affichée dans le PRD), une
migration vers un algorithme dédié aux mots de passe (Argon2id/bcrypt) est
recommandée. La signature de `PasswordHasher` a été pensée pour que ce changement
futur n'impacte aucun autre fichier.

### Verrouillage après échecs : suivi en mémoire, pas persistant
La règle du Processus 1 ("3 tentatives échouées → verrouillage 60 secondes") vise à
ralentir une tentative automatisée en direct, pas à sanctionner durablement un
compte — cette dernière responsabilité appartient explicitement à la désactivation
de compte par l'Administrateur (`setActive`), un mécanisme distinct et persistant.
Un redémarrage de l'application réinitialise donc le compteur de tentatives ; c'est
un choix assumé et documenté dans `login_attempt_tracker.dart`, pas un oubli.

### Le compte désactivé n'incrémente jamais le compteur d'échecs
Choix délibéré, testé explicitement (`auth_service_test.dart`) : un compte désactivé
qui tente de se connecter avec le bon mot de passe ne doit pas être traité comme une
attaque par force brute, seulement informé que son compte n'est plus actif.

### `DatabaseSeeder` : résoudre le problème du "premier compte"
Sans compte existant, personne ne peut se connecter pour en créer un premier. Le
seeder crée un compte Administrateur par défaut uniquement si la table des
utilisateurs est vide, avec un mot de passe qui doit être changé immédiatement — un
avertissement explicite est journalisé (`AppLogger.warning`) à chaque fois que ce
cas se produit, pour qu'il ne passe jamais inaperçu en environnement réel.

### Migration de schéma (v1 → v2) plutôt que recréation
`UsersTable` a été ajoutée via `MigrationStrategy.onUpgrade`, pas en modifiant
`onCreate` seul : une base déjà initialisée par le Module 1 ne perd aucune donnée
locale (`AppMetadataTable`, `SyncEventsTable`) lors de la mise à jour vers ce module.

---

## 3. Dépendances ajoutées

| Paquet | Rôle |
|---|---|
| `crypto` | Hachage SHA-256 des mots de passe (voir justification ci-dessus) |

Aucune autre dépendance n'a été nécessaire : le reste du module s'appuie
entièrement sur ce qui était déjà posé au Module 1 (Drift, Riverpod, go_router,
flutter_secure_storage, uuid, logger).

---

## 4. Tests réalisés

- `password_hasher_test.dart` — deux sels distincts, vérification correcte/incorrecte,
  un même mot de passe produit des hash différents selon le sel.
- `login_attempt_tracker_test.dart` — pas de verrouillage sous le seuil, verrouillage
  au seuil exact, `reset()` efficace, compteurs indépendants par identifiant.
- `auth_service_test.dart` (le plus important) — couvre very précisément le
  Processus 1 : connexion réussie, identifiant inconnu, mauvais mot de passe, compte
  désactivé (avec vérification du message exact), verrouillage après 3 échecs même
  avec le bon mot de passe ensuite, réinitialisation du compteur après un succès.

Ces tests utilisent `FakeUserRepository` (en mémoire) : ils s'exécutent donc sans
dépendre de Drift ni d'un appareil, ce qui les rend rapides et fiables en intégration
continue future.

### Même limite technique que le Module 1
Comme indiqué au module précédent, cet environnement de conception ne dispose pas du
SDK Flutter/Dart : ces tests n'ont **pas pu être exécutés concrètement** ici. Ils ont
été écrits pour s'exécuter avec `flutter test` dans un environnement de
développement standard, après régénération de `local_database.g.dart` (nécessaire
car `UsersTable` a été ajoutée).

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

Résultat attendu de `flutter run` : au premier démarrage (base vide), les logs
affichent la création du compte administrateur par défaut ; l'écran de connexion
réel accepte cet identifiant, redirige vers l'accueil Administrateur, où le bouton
"Gérer les comptes utilisateurs" permet de créer un compte Préparateur ou Coursier,
de le désactiver/réactiver, et de réinitialiser son mot de passe. Se connecter avec
un compte désactivé doit afficher exactement le message "Ce compte n'est plus
actif...". Trois échecs de mot de passe consécutifs doivent bloquer une quatrième
tentative pendant 60 secondes, y compris avec le bon mot de passe.

---

## 5. Points validés

- [x] Vérification réelle des identifiants (Processus 1), avec les trois cas exacts :
      succès, identifiant/mot de passe incorrect, compte désactivé.
- [x] Verrouillage après 3 tentatives échouées, pendant 60 secondes, conforme au
      Processus 1 et au document Processus métier V1.
- [x] Rôle déterminé automatiquement à la connexion et session persistée via le
      `SessionManager` du Module 1, sans modification de celui-ci.
- [x] Gestion des comptes côté Administrateur : création, désactivation/réactivation,
      réinitialisation de mot de passe (Cahier des charges, écran 4.14).
- [x] Mots de passe jamais stockés en clair (hachage salé, sel unique par compte).
- [x] Bootstrap résolu : un compte administrateur par défaut est créé automatiquement
      si aucun compte n'existe, avec avertissement explicite dans les logs.
- [x] Migration de schéma de base locale sans perte de données (v1 → v2).
- [x] Tests unitaires couvrant chaque cas du Processus 1, exécutables sans Drift ni
      appareil réel (dépôt en mémoire dédié aux tests).
- [ ] Non concerné par ce module (volontairement) : synchronisation réelle des
      comptes avec un serveur central (Module 7), tableau de bord complet de
      l'Administrateur au-delà de la gestion des comptes (Module 8).

**Prochaine étape** : Module 3 — Téléchargement des tournées, qui viendra consommer
le rôle `préparateur` déjà géré ici pour assigner et télécharger des tournées, sans
modifier ce module.
