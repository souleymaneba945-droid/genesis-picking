# GENESIS PICKING

Assistant de préparation de commandes hors-ligne pour **Univers Parapharmacie**
(Dakar). Trois rôles partagent une seule application — Administrateur,
Préparateur, Coursier — chacun avec son propre accueil et sa propre navigation,
protégés par un contrôle de rôle centralisé.

- **Préparateur** : télécharge une tournée, la pique produit par produit,
  signale les "produit introuvable" à un coursier.
- **Coursier** : reçoit les demandes de vérification, retrouve ou confirme
  l'absence du produit, avec l'emplacement entrepôt connu si la marque est
  répertoriée.
- **Administrateur** : importe les tournées (PDF calibré, ou CSV/Excel/JSON),
  gère les comptes, suit les demandes coursier en temps réel, cartographie les
  emplacements entrepôt par marque, et consulte les statistiques de demande
  logistique (quelles marques/références reviennent le plus souvent, et où).

Toute l'application est **offline-first** : le picking et la navigation ne
dépendent jamais du réseau. Une synchronisation réelle entre appareils
(Firestore) reste best-effort — une panne réseau ne bloque jamais une action
locale, elle retarde seulement sa visibilité sur les autres appareils.

---

## 1. Architecture

### `core/` vs `features/`

- `lib/core/` — tout ce qui est transverse et stable : configuration, gestion
  d'erreurs (`Result<T>` + `AppException`), logs, thème, i18n, navigation,
  session, stockage local (Drift), mécanique de file de synchronisation.
- `lib/features/<nom>/` — un dossier par module métier, chacun typiquement
  découpé en `data/` (modèles, interfaces de repository + implémentations
  Drift), `domain/` (services — règles métier) et `presentation/`
  (contrôleurs Riverpod + écrans/widgets).

```
lib/
├── main.dart                      # Point d'entrée (Firebase, config, capture d'erreurs)
├── app.dart                       # Widget racine (MaterialApp.router)
│
├── core/
│   ├── config/                    # Environnement (dev/staging/prod), constantes
│   ├── errors/                    # AppException, Result<T>, ErrorHandler
│   ├── logging/                   # AppLogger (jamais de print())
│   ├── navigation/                # go_router + AppNavigationGuard (redirections par rôle)
│   ├── notifications/             # Notifications locales (coursier, premier plan)
│   ├── providers/                 # Providers Riverpod transverses
│   ├── session/                   # SessionManager, UserRole, UserSession
│   ├── storage/                   # LocalDatabase (Drift) + toutes les tables
│   ├── sync/                      # SyncQueue (enqueue) + SyncService/SimulatedSyncTransport
│   ├── theme/                     # AppColors/AppDimensions/AppTypography/AppTheme — source unique
│   └── widgets/                   # Composants partagés (boutons, cartes de statut, chips, avatars…)
│
└── features/
    ├── auth/                      # Connexion, hachage/verrouillage, sync des comptes
    ├── user_management/           # CRUD comptes, révocation, renommage d'identifiant
    ├── tours/                     # Téléchargement/liste/reprise d'une tournée
    ├── picking/                   # Moteur de picking (produit par produit)
    ├── courier/                   # Demandes "produit introuvable" + écrans coursier
    ├── warehouse_location/        # Cartographie emplacement entrepôt par marque (import en masse)
    ├── sync/                      # Moteur de synchronisation (drain de la file)
    ├── administration/            # Tableau de bord, suivi, statistiques de demande logistique
    ├── import/                    # Import de tournée : PDF calibré, CSV/Excel/JSON
    ├── profile/ , settings/       # Profil, paramètres, diagnostic
    └── splash/                    # Écran de démarrage
```

### Sync : deux mécanismes distincts, ne pas les confondre

- **File `SyncQueue`** (`core/sync/`) : les modules métier y déposent des
  événements (fire-and-forget). Le moteur `SyncService`/
  `SimulatedSyncTransport` qui devait la vider n'est **pas branché à un vrai
  backend** — c'est un chantier resté en l'état.
- **Firebase/Firestore** (projet `genesis-picking-univers`) : le vrai chemin
  de synchronisation entre appareils, utilisé par `tours/`, `auth/`,
  `courier/`, `warehouse_location/`. Chaque module y pousse ses écritures en
  best-effort juste après l'écriture locale (jamais bloquant, jamais
  annulé en cas d'échec réseau) et peut les retirer (`pullAll`, flux `watch`).
  Authentification Firebase **non utilisée** — l'authentification par mot de
  passe local reste la seule porte d'entrée, Firestore n'est qu'un relais de
  données.

### Stockage local : Drift (SQLite)

Une seule `LocalDatabase` assemble toutes les tables de tous les modules.
Schéma versionné, migrations additives uniquement (`if (from < N) { ... }`,
jamais de modification d'une étape déjà publiée). `local_database.g.dart` est
généré, jamais modifié à la main — voir la commande `build_runner` ci-dessous.

---

## 2. Dépendances principales

| Paquet | Rôle |
|---|---|
| `go_router` | Navigation déclarative, redirection centralisée par rôle |
| `flutter_riverpod` | Gestion d'état, injection de dépendances testable |
| `drift` / `drift_flutter` | Base de données locale offline-first |
| `firebase_core` / `cloud_firestore` | Synchronisation réelle entre appareils |
| `flutter_secure_storage` | Persistance sécurisée de la session |
| `crypto` | Hachage des mots de passe (PBKDF2) |
| `connectivity_plus` | Détection de l'état réseau |
| `syncfusion_flutter_pdf` / `pdfrx` / `image` | Import de tournée depuis un PDF calibré (texte + photo produit) |
| `csv` / `excel` | Import de tournée depuis un fichier CSV/Excel |
| `file_picker` / `desktop_drop` | Sélection ou glisser-déposer d'un fichier d'import |
| `cached_network_image` | Cache disque des photos produit (consultables hors-ligne une fois vues) |
| `flutter_local_notifications` | Notification coursier en premier/arrière-plan |
| `logger` | Journalisation structurée (aucun `print()` dans le code) |

Le détail et la justification de chaque dépendance sont commentés directement
dans `pubspec.yaml`.

---

## 3. Commandes

```bash
flutter pub get                                                   # installer les dépendances
dart run build_runner build --delete-conflicting-outputs          # régénérer local_database.g.dart après toute table/@DriftDatabase modifiée
flutter analyze                                                   # lint
flutter test                                                      # tous les tests
flutter test test/features/picking/picking_service_test.dart      # un seul fichier de test
flutter run                                                        # lancer l'application
```

---

## 4. Tests

Pas de framework de mock : les tests de `domain`/`data` utilisent des fakes
écrits à la main (`FakeXxxRepository`) implémentant les mêmes interfaces que
les implémentations Drift/Firestore réelles. Aucun test widget/intégration/
navigation n'existe encore (limite connue, voir `MODULE_9.md`) — la couverture
porte sur la logique métier et les données, pas sur le rendu.

État actuel : ~30 fichiers de test, 264 tests, tous verts (`flutter analyze`
sans erreur ni avertissement).

---

## 5. Dette technique connue (documentée, pas un oubli)

- `core/l10n/` existe mais n'est jamais appelé : tous les écrans codent leur
  texte français en dur.
- Un compte administrateur par défaut est créé au premier lancement si aucun
  n'existe ; rien n'impose de changer son mot de passe.
- Les règles Firestore (`firestore.rules`, `storage.rules`) sont ouvertes
  (`allow read, write: if true`) — acceptable pour une petite équipe interne
  de confiance, à revoir si l'app ou la configuration Firebase sort de ce
  cercle. Firebase Storage n'est en réalité pas activé (plan Blaze
  indisponible) : les photos partent en `data:` URI directement dans
  Firestore, la règle `storage.rules` reste donc dormante.
- `core/sync/SyncService`/`SimulatedSyncTransport` (la file de synchronisation
  d'origine) n'a jamais été branché à un vrai backend — ne pas le confondre
  avec le chemin Firestore réel, qui le contourne entièrement (voir section 1).

---

## 6. Historique

Développé de façon incrémentale, un module par commit — voir `MODULE_2.md` à
`MODULE_9.md` (et `MODULE_5_V2.md`, `MODULE_IMPORT.md`) pour le détail et les
arbitrages de chaque étape. Les principes ayant guidé les choix
d'architecture (couches, Riverpod, Drift, erreurs, navigation) restent ceux
posés au tout début du projet et n'ont jamais eu besoin d'être remis en
cause — seuls `features/` et les tables ont grandi module après module.
