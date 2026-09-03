# GENESIS PICKING — Module 1 : Fondation du projet

Ce module ne développe **aucune fonctionnalité métier**. Il met en place la structure
professionnelle sur laquelle les modules 2 à 10 seront construits, chacun dans son
propre commit, sans jamais revenir sur les choix de ce module sans raison documentée.

---

## 1. Arborescence complète du projet

```
genesis_picking/
├── analysis_options.yaml          # Règles de lint (flutter_lints + règles projet)
├── pubspec.yaml                   # Dépendances (section 3)
├── .gitignore
├── README.md                      # Ce document
│
├── assets/
│   └── l10n/
│       └── app_fr.arb             # Textes français (source unique de vérité)
│
├── lib/
│   ├── main.dart                  # Point d'entrée unique
│   ├── app.dart                   # Widget racine (MaterialApp.router)
│   │
│   ├── core/                      # Tout ce qui est transverse aux modules métier
│   │   ├── config/
│   │   │   ├── app_config.dart        # Configuration globale (singleton contrôlé)
│   │   │   └── environment.dart       # dev / staging / prod
│   │   ├── constants/
│   │   │   └── app_constants.dart     # Constantes globales uniquement
│   │   ├── errors/
│   │   │   ├── app_exception.dart     # Hiérarchie d'exceptions métier
│   │   │   ├── error_handler.dart     # Capture globale + messages utilisateur
│   │   │   └── result.dart            # Result<T> pour la gestion fonctionnelle
│   │   ├── l10n/
│   │   │   └── app_localizations.dart # Système d'i18n (prêt, FR actif)
│   │   ├── logging/
│   │   │   └── app_logger.dart        # Journalisation centralisée
│   │   ├── navigation/
│   │   │   ├── app_router.dart        # go_router + redirections par rôle
│   │   │   └── app_routes.dart        # Noms de routes centralisés
│   │   ├── providers/
│   │   │   └── core_providers.dart    # Providers Riverpod du socle
│   │   ├── session/
│   │   │   ├── session_manager.dart   # Persistance de session (secure storage)
│   │   │   ├── user_role.dart         # Enum des 3 rôles + conversion stockage
│   │   │   └── user_session.dart      # Modèle immuable de session
│   │   ├── storage/
│   │   │   ├── local_database.dart        # Base Drift (assemblage des tables)
│   │   │   ├── local_storage_service.dart  # Interface abstraite
│   │   │   └── tables/
│   │   │       └── app_metadata_table.dart # Table clé/valeur générique
│   │   ├── sync/
│   │   │   ├── sync_event.dart        # Modèle + table de la file de synchro
│   │   │   ├── sync_manager.dart      # Orchestrateur (structure uniquement)
│   │   │   └── sync_queue.dart        # Ajout/lecture de la file locale
│   │   ├── theme/
│   │   │   ├── app_colors.dart        # Palette officielle (Document UX/UI)
│   │   │   ├── app_dimensions.dart    # Espacements et tailles standard
│   │   │   ├── app_theme.dart         # ThemeData unique de l'application
│   │   │   └── app_typography.dart    # Échelle typographique
│   │   └── widgets/                   # Composants réutilisables
│   │       ├── buttons/
│   │       │   ├── primary_button.dart
│   │       │   └── secondary_button.dart
│   │       ├── feedback/
│   │       │   └── app_snackbar.dart
│   │       ├── layout/
│   │       │   └── app_scaffold.dart
│   │       └── status/
│   │           └── sync_status_indicator.dart
│   │
│   └── features/                  # PROVISOIRE — un seul écran par point
│       │                          # d'ancrage de navigation, pour prouver
│       │                          # que le socle fonctionne de bout en bout.
│       │                          # Chacun sera remplacé par son module dédié.
│       ├── splash/
│       │   └── splash_screen.dart
│       ├── login_placeholder/
│       │   └── login_placeholder_screen.dart
│       └── home_placeholder/
│           └── role_home_placeholder_screen.dart
│
└── test/
    └── core/
        ├── errors/
        │   ├── error_handler_test.dart
        │   └── result_test.dart
        └── session/
            └── user_role_test.dart
```

**Ce qui n'existe volontairement pas encore** : aucune table métier (tournées,
produits, demandes coursier), aucun écran de picking, aucune logique de coursier,
aucune transmission réseau réelle. Ces éléments arrivent avec les modules 2 à 8.

---

## 2. Justification des choix d'architecture

### Structure en couches (`core/` vs `features/`)
`core/` contient tout ce qui est transverse et stable ; `features/` contiendra le code
propre à chaque module métier. Cette séparation permet de développer et tester un
module sans jamais modifier le socle — conforme à l'exigence de modularité de la
Directive de développement.

### Gestion d'état : Riverpod
Choisi pour trois raisons directement liées aux contraintes du projet :
- **Testabilité** — chaque provider est remplaçable en test sans dépendance à un
  widget monté, ce qui permettra de tester la logique du Module 4 (picking) sans
  jamais lancer un écran réel.
- **Explicite** — un module ne peut lire l'état d'un autre qu'en déclarant
  explicitement sa dépendance (`ref.watch(...)`), ce qui rend visible tout couplage
  entre modules et empêche les dépendances cachées.
- **Cycle de vie maîtrisé** — `ref.onDispose` garantit que la base locale et le
  gestionnaire de synchronisation sont proprement libérés, cohérent avec l'exigence
  de robustesse (Architecture technique, section 9).

### Base de données locale : Drift (SQLite)
Retenu tel que déjà justifié dans l'Architecture technique validée : typage fort,
migrations gérées, et surtout **requêtes réactives** — un futur écran de picking
pourra observer un flux de données local sans code de rafraîchissement manuel, ce qui
sert directement l'exigence "chaque écran s'affiche instantanément".

### Navigation : go_router avec redirection centralisée
La logique de redirection selon le rôle (`_homeRouteFor`) est écrite à un seul
endroit (`app_router.dart`), jamais dupliquée dans les écrans. Cela évite qu'un futur
module introduise, par erreur, un chemin de navigation qui contourne le contrôle de
rôle — un point sensible vu les exigences strictes de droits (Cahier des charges,
section 1 ; PRD, chapitre 3).

### Sessions : persistance séparée de la logique d'authentification
`SessionManager` (Module 1) ne fait que persister/restituer une session déjà validée.
La vérification réelle des identifiants (Processus 1) sera ajoutée par le Module 2,
**sans modifier ce fichier** — seulement en l'appelant. C'est la démonstration
concrète de la modularité demandée : un module futur consomme le socle, il ne le
réécrit pas.

### Erreurs : hiérarchie `AppException` + `Result<T>`
Deux mécanismes complémentaires :
- `Result<T>` oblige chaque appelant à traiter explicitement un échec, dans les
  couches internes (pas de `try/catch` oublié).
- `ErrorHandler.userMessageFor()` centralise la traduction technique → message
  utilisateur, avec les textes déjà validés dans le PRD (chapitre 9). Aucun écran
  futur n'aura à réinventer un message d'erreur.
- `ErrorHandler.initializeGlobalCapture()` garantit qu'aucune erreur, même imprévue,
  ne fait planter silencieusement l'application — conforme au Processus 10 (« vos
  données sont conservées »).

### Offline First : file de synchronisation dès le Module 1, transmission au Module 7
Conformément à la demande explicite ("système de synchronisation - structure
uniquement"), `SyncQueue` et `SyncManager` posent la mécanique (table locale,
détection réseau, point d'entrée `triggerSync()`) sans implémenter le protocole
réseau réel. Cela permet aux Modules 3, 4 et 5 d'enregistrer déjà leurs événements
(téléchargement de tournée, validation de produit, demande coursier) dans cette file
dès leur développement, sans attendre le Module 7 pour être eux-mêmes "offline-first".

### Internationalisation : implémentation autonome plutôt que génération de code
Une approche par fichiers `.arb` chargés directement (`AppLocalizationsDelegate`) a
été choisie plutôt que la génération officielle `flutter gen-l10n`, pour une raison
pratique : elle ne nécessite aucune étape de build supplémentaire pour rester
utilisable immédiatement dans n'importe quel environnement de développement, tout en
gardant exactement la même API (`AppLocalizations.of(context)`) si l'équipe choisit
plus tard de migrer vers la génération officielle.

---

## 3. Dépendances utilisées

| Paquet | Rôle | Pourquoi ce choix |
|---|---|---|
| `go_router` | Navigation déclarative | Redirection centralisée par rôle, sans code de navigation dispersé dans les écrans |
| `flutter_riverpod` | Gestion d'état | Testabilité, dépendances explicites (voir section 2) |
| `drift` + `sqlite3_flutter_libs` | Base de données locale | Offline First, requêtes réactives, migrations gérées |
| `path_provider` / `path` | Localisation du fichier de base de données sur l'appareil | Nécessaire à Drift en environnement mobile |
| `flutter_secure_storage` | Persistance sécurisée de la session | Le jeton de session ne doit jamais être stocké en clair |
| `connectivity_plus` | Détection de l'état réseau | Fondement du principe Offline First |
| `uuid` | Identifiants uniques des événements de synchronisation | Évite les doublons lors d'un renvoi après échec (Processus 7) |
| `logger` | Journalisation structurée | Remplace tout usage de `print()` (voir `analysis_options.yaml`) |
| `flutter_lints` | Règles de qualité de code | Base standard, complétée par des règles projet |
| `drift_dev` / `build_runner` | Génération de code (dev uniquement) | Requis par Drift pour générer `local_database.g.dart` |

Aucune dépendance métier (parsing PDF, scan, etc.) n'a été ajoutée à ce stade —
conformément à la consigne de ne développer aucune fonctionnalité métier.

---

## 4. Tests réalisés

### Tests automatisés inclus dans ce livrable
- `test/core/errors/result_test.dart` — comportement de `Result<T>` (succès, échec,
  propagation dans `map`, consommation via `when`).
- `test/core/errors/error_handler_test.dart` — vérifie que chaque type d'exception
  produit exactement le message utilisateur validé dans le PRD (chapitre 9).
- `test/core/session/user_role_test.dart` — vérifie que la conversion rôle ↔
  stockage est réversible pour les trois rôles, et qu'une clé invalide échoue
  explicitement plutôt que silencieusement.

### Limite technique de cet environnement de conception
Ce document a été rédigé et le code écrit dans un environnement qui ne dispose pas du
SDK Flutter/Dart ni d'accès à `pub.dev` : il n'a donc **pas été possible d'exécuter
concrètement** `flutter pub get`, `dart run build_runner build` (génération du fichier
`local_database.g.dart` requis par Drift), `flutter analyze` ni `flutter test` dans cet
environnement. Le code a été écrit et relu avec la plus grande rigueur pour être
directement compilable dans un environnement Flutter standard, mais je le signale
explicitement plutôt que de prétendre à une validation que je n'ai pas pu effectuer.

### À exécuter en tout premier lieu dans votre environnement de développement
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # génère local_database.g.dart
flutter analyze
flutter test
flutter run
```
Le résultat attendu de `flutter run` : l'application démarre sur l'écran de
démarrage, redirige vers l'écran de connexion provisoire, permet de choisir un rôle,
affiche l'accueil correspondant avec l'indicateur de synchronisation dans l'AppBar, et
la déconnexion ramène à l'écran de connexion. Fermer et rouvrir l'application après
connexion doit ramener directement à l'accueil du rôle (test manuel de la
restauration de session, Processus 1).

---

## 5. Points validés

- [x] Architecture du projet (séparation `core/` / `features/`) en place.
- [x] Organisation des dossiers cohérente avec les modules à venir (un sous-dossier
      `features/<module>` par module, sans anticiper leur contenu).
- [x] Navigation fonctionnelle avec redirection selon le rôle et protection des
      routes (un utilisateur non connecté ne peut atteindre aucun accueil).
- [x] Thème global, couleurs, typographie appliqués conformément au Document UX/UI.
- [x] Composants réutilisables de base (boutons, scaffold, indicateur de synchro,
      snackbar) posés et déjà utilisés par les écrans provisoires.
- [x] Gestion des rôles (enum + conversion de stockage) posée.
- [x] Gestion de session (ouverture, restauration, fermeture) posée et persistée de
      façon sécurisée.
- [x] Stockage local (Drift) posé, avec une table transverse de démonstration.
- [x] Système de logs centralisé, aucun `print()` dans le code.
- [x] Système de configuration (environnements) posé.
- [x] Gestion des erreurs globale : capture des erreurs non interceptées + traduction
      en messages utilisateur conformes au PRD.
- [x] Mode Offline First : file de synchronisation locale posée et déjà utilisable
      par un futur module.
- [x] Structure de synchronisation posée (détection réseau, point d'entrée), sans
      transmission réseau réelle — conforme à la consigne du Module 1.
- [x] Internationalisation prête (français actif, structure extensible).
- [ ] Non concerné par ce module (volontairement) : authentification réelle, écran de
      picking, logique coursier, transmission de synchronisation réelle,
      administration — voir Modules 2 à 8.

**Prochaine étape** : Module 2 — Authentification et gestion des utilisateurs, qui
viendra remplacer `login_placeholder_screen.dart` par la vérification réelle des
identifiants (Processus 1) sans modifier le socle posé ici.
