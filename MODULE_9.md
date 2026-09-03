# GENESIS PICKING — Module 9 : Stabilisation, Optimisation et Qualité

Aucune fonctionnalité nouvelle, aucun nouvel écran, aucun changement de
comportement métier. Ce document est à la fois le rapport d'audit, le rapport de
performance, le rapport de sécurité, le résumé de couverture de tests, la liste des
corrections et la checklist finale demandés par la Directive.

---

## 1. Rapport d'audit

### 1.1 Code mort / fichiers obsolètes — corrigé
| Élément | Constat | Action |
|---|---|---|
| `TourProductLine` (Module 3) | Classe définie mais jamais instanciée : le Module 4 a construit `PickingProduct` à la place et n'a jamais consommé ce modèle. | Fichier supprimé ; commentaires orphelins dans `tour.dart` et `tour_remote_source.dart` corrigés. |
| `SyncQueue.markAsSynced()` / `markAsFailed()` (Module 1) | Plus aucun appelant depuis que `SyncRepository` (Module 6) assure ce rôle pour le vrai moteur. | Méthodes supprimées ; `pendingEvents()` conservée (toujours utilisée par `SyncManager`). |
| `features/home_placeholder/` | Déjà supprimé au Module 8, une fois les trois rôles dotés d'un vrai écran. | Rien à faire — vérifié à nouveau, aucune référence restante. |

### 1.2 Dépendances inutiles — corrigé
| Dépendance | Constat | Action |
|---|---|---|
| `cupertino_icons` | Aucune occurrence de `CupertinoIcons` dans tout le projet (uniquement des icônes Material). | Retirée de `pubspec.yaml`. |
| `sqlite3_flutter_libs` | Zéro `import` Dart direct — **normal** : ce paquet embarque les binaires natifs SQLite consommés par `drift`/`sqlite3` en coulisses, sans API Dart à importer. | Conservée : dépendance légitime, vérifiée plutôt que supprimée à tort. |

### 1.3 Incohérence d'architecture identifiée — NON corrigée (documentée)
Le système d'internationalisation (`AppLocalizations`, Module 1) n'est **appelé nulle
part** : tous les écrans écrivent leurs textes en français directement, en dur.
Le résultat visible est strictement identique (l'application n'a jamais eu qu'une
langue active), donc ce n'est pas un bug fonctionnel — mais c'est une infrastructure
construite puis jamais branchée. La reconnexion complète toucherait des dizaines
d'écrans pour un gain nul aujourd'hui : plutôt que de le faire à la hâte sans
pouvoir vérifier chaque écran (`flutter run` indisponible dans cet environnement),
c'est consigné comme dette technique explicite (section 10) avec une recommandation
claire plutôt que traité superficiellement.

### 1.4 Classes/fichiers trop longs — corrigé
`picking_screen.dart` regroupait 5 classes (l'écran + 4 widgets) sur 358 lignes.
Éclaté en :
- `picking_screen.dart` (164 lignes) — l'écran seul.
- `widgets/progress_bar.dart`, `widgets/product_card.dart` (+`ImagePlaceholder`),
  `widgets/tour_complete_view.dart` — un widget par fichier.

Aucun autre fichier ne dépasse 260 lignes ; le projet (102 fichiers `lib/`, environ
7 400 lignes avant ce module) ne présente pas d'autre cas de classe manifestement
trop longue au vu de sa complexité réelle.

### 1.5 Méthodes trop complexes
Aucune méthode ne dépasse une trentaine de lignes avec un seul niveau de
responsabilité, à l'exception de `SyncService.synchronizeNow()` (boucle de
traitement), déjà décomposée en sous-méthodes privées (`_processOperation`,
`_handleFailure`) lors de son écriture au Module 6 — relu, jugé approprié tel quel.

### 1.6 Code dupliqué
Le seul doublon structurel identifié est le chevauchement partiel entre
`SyncQueue` (dépôt d'événements) et `SyncRepository` (lecture/écriture pour le
moteur) — déjà documenté et justifié dans `MODULE_6.md` comme une séparation
volontaire de responsabilités plutôt qu'une duplication accidentelle ; confirmé lors
de cet audit, rien à corriger.

### 1.7 Imports inutilisés
Un balayage manuel n'a pas trouvé d'autre import mort que ceux déjà retirés en
même temps que le code associé (section 1.1). Une vérification exhaustive et fiable
nécessiterait `flutter analyze`, indisponible dans cet environnement (voir
Limitations, section 11) — signalé honnêtement plutôt que déclaré résolu à tort.

---

## 2. Rapport de performance

| Aspect vérifié | Constat | Action |
|---|---|---|
| Ouverture de l'application | Séquence du splash (ouverture DB, seed, restauration session, init sync) : toutes des opérations locales, aucun appel réseau bloquant. | Aucune action nécessaire. |
| Changement de produit (picking) | État géré localement dans `PickingController`, aucune re-requête réseau ; la quantité repart de la valeur demandée sans calcul. | Aucune action nécessaire. |
| **Affichage des listes de produits (N+1 requêtes)** | `DriftProductRepository.listForTour()` et `ensureStatusesInitialized()` exécutaient **une requête SQL par produit** pour lire/initialiser son état. | **Corrigé** : une seule requête groupée (`WHERE productLineId IN (...)`) remplace la boucle, plus une insertion en lot (`batch`) pour l'initialisation. Comportement strictement identique, nombre de requêtes divisé par la taille de la tournée. |
| Consommation mémoire | Voir section 3 (gestion mémoire) — aucune fuite identifiée. | — |
| Stockage local | Toutes les tables sont indexées par clé primaire ; aucune requête sans clause `WHERE` sur une table volumineuse. | Aucune action nécessaire. |
| Navigation | `go_router` pour les 3 racines, `Navigator.push` classique pour le reste — pas de reconstruction inutile de l'arbre de navigation. | Aucune action nécessaire. |
| Point mineur non corrigé | `DriftCourierRepository.countOpenRequestsFor()` charge toutes les lignes d'un coursier puis filtre en Dart plutôt qu'un `COUNT` SQL avec clause `WHERE`. Négligeable au volume attendu (quelques dizaines de demandes par coursier), noté pour une optimisation future si le volume augmentait fortement. | Non corrigé (impact réel nul au volume actuel). |

---

## 3. Gestion mémoire

| Ressource | Vérification | Résultat |
|---|---|---|
| `TextEditingController` (3 écrans : connexion, création de compte, réinitialisation de mot de passe) | Chaque écran possède un `dispose()` qui libère tous ses contrôleurs. | Aucune fuite. |
| `StreamController` (`SyncManager`, `NetworkMonitor`) | Fermés dans leurs `dispose()` respectifs. | Aucune fuite. |
| `StreamSubscription` (`SyncManager`, `NetworkMonitor`, `SyncService`) | Chacune annulée (`.cancel()`) dans le `dispose()` correspondant. | Aucune fuite. |
| Câblage des `dispose()` avec Riverpod | `localDatabaseProvider`, `networkMonitorProvider`, `syncManagerProvider`, `syncServiceProvider` appellent tous `ref.onDispose(...)`. | Aucun `dispose()` orphelin. |
| Écouteurs oubliés | Recherche de tout `.listen(` sans `StreamSubscription` conservée pour annulation ultérieure. | Aucun cas trouvé. |

---

## 4. Gestion des erreurs

| Vérification | Constat avant | Action |
|---|---|---|
| Capture globale des erreurs Flutter/asynchrones | `ErrorHandler.initializeGlobalCapture()` posé au Module 1, actif depuis `main()`. | Vérifié toujours actif, inchangé. |
| **Branches d'erreur des `FutureBuilder`** | **8 écrans** (Tableau de bord admin, Historique, Demandes coursier admin, Gestion des comptes, Choix du coursier, Mes demandes coursier, Détail demande coursier, Mes tournées) ne testaient que `snapshot.hasData` : une erreur inattendue aurait laissé un indicateur de chargement infini plutôt qu'un message explicite. | **Corrigé sur les 8 écrans** : ajout systématique d'une branche `snapshot.hasError` avec un message clair, avant la vérification `hasData`. |
| Traduction technique → message utilisateur | `ErrorHandler.userMessageFor()` couvre toutes les sous-classes de `AppException`. | Vérifié exhaustif. |
| Erreurs de synchronisation | `SyncService` capture toute exception de transport et la transforme en nouvel état d'opération, sans jamais la laisser remonter. | Vérifié, inchangé. |

---

## 5. Rapport de sécurité

| Aspect | Constat | Action |
|---|---|---|
| Stockage local | Session (jeton, rôle, identifiant) via `flutter_secure_storage` ; mots de passe jamais stockés en clair, hachage salé. | Vérifié, inchangé. |
| Journalisation | Recherche explicite de toute trace de mot de passe dans les appels `AppLogger` : aucune occurrence. | Vérifié, aucune fuite dans les logs. |
| **Contrôle d'accès par rôle au niveau du routeur** | **Faille identifiée** : le routeur vérifiait qu'une session existait, mais jamais que le rôle de la session correspondait à la route d'accueil demandée. Un utilisateur authentifié aurait pu, en théorie, atteindre l'accueil d'un autre rôle. | **Corrigé** : le routeur renvoie désormais vers le véritable accueil du rôle de la session si l'utilisateur tente d'atteindre l'accueil d'un autre rôle. |
| Compte administrateur par défaut | `DatabaseSeeder` crée un compte "admin" avec un mot de passe fixe codé dans le binaire si aucun compte n'existe. Un avertissement invite à le changer, mais rien ne l'impose techniquement. | **Non corrigé** (imposer un changement de mot de passe serait une nouvelle fonctionnalité) — documenté comme risque connu. |
| Permissions système | Aucune permission sensible demandée (caméra, localisation, contacts...). | Vérifié, rien à signaler. |
| Application des droits par rôle en dehors de l'UI | Aucune vérification côté serveur n'existe, car aucun serveur réel n'existe encore. Le contrôle d'accès repose sur l'interface et, désormais, le routeur. | Limitation architecturale acceptée : à répéter côté serveur dès qu'il existera. |

---

## 6. Couverture de tests

Le projet compte **102 fichiers source** (`lib/`) et **13 fichiers de tests**
(`test/`), totalisant **≈87 cas de test unitaires** :

| Module | Fichiers de test | Cas |
|---|---|---|
| Module 1 (socle) | `result_test.dart`, `error_handler_test.dart` | 9 |
| Module 2 (authentification) | `auth_service_test.dart`, `login_attempt_tracker_test.dart`, `password_hasher_test.dart`, `user_role_test.dart` | 16 |
| Module 3 (tournées) | `tour_service_test.dart`, `tour_repository_test.dart` | 15 |
| Module 4 (picking) | `picking_service_test.dart` | 8 |
| Module 5 (coursier) | `courier_service_test.dart` | 13 |
| Module 6 (synchronisation) | `sync_service_test.dart`, `conflict_resolver_test.dart` | 20 |
| Module 8 (administration) | `administration_service_test.dart` | 6 |

### Ce qui n'est pas couvert (gap honnête)
- **Aucun test de widget/écran**, aucun test d'intégration ni de navigation de
  bout en bout.
- **Aucun des ≈87 tests n'a pu être exécuté réellement** dans cet environnement
  (absence du SDK Flutter/Dart) : leur correction a été vérifiée par relecture, pas
  par exécution.

Les tests unitaires couvrent la logique métier de chaque module, y compris les
scénarios hors connexion et de synchronisation. Les tests d'intégration et de
navigation nécessitent un harnais Flutter que cet environnement ne permet pas
d'exécuter ni de vérifier fiablement — en écrire sans pouvoir les faire tourner
aurait donné un faux sentiment de couverture. Recommandation prioritaire pour la
phase de recette (section 10).

---

## 7. Analyse de robustesse

| Scénario | Analyse |
|---|---|
| Fermeture brutale | Chaque action est écrite en base locale immédiatement, jamais en mémoire seule. Une fermeture à tout moment ne perd que la saisie non confirmée. |
| Batterie faible / extinction | Identique : aucune donnée n'existe uniquement en mémoire volatile au-delà de la saisie non confirmée. |
| Mémoire saturée | Le stockage repose sur SQLite (Drift) ; aucune collection non bornée n'est conservée en mémoire application (section 3). |
| Absence réseau | Principe Offline First appliqué de bout en bout ; `SyncService` ne bloque jamais l'utilisateur. |
| Réseau instable | `SyncService` vérifie la connexion avant chaque opération de la boucle, pas seulement au début. |
| Reprise après redémarrage | Chaque module recalcule son état à partir de la base locale, jamais d'un état en mémoire supposé. |

Aucune régression identifiée par rapport aux garanties déjà posées module par
module ; ce module a corrigé les deux angles morts trouvés (routeur, `FutureBuilder`).

---

## 8. Qualité du code

- **Nommage** cohérent : français pour le domaine métier, anglais pour
  l'infrastructure transverse.
- **Documentation publique** : chaque classe publique porte un commentaire `///`
  expliquant son rôle et sa justification vis-à-vis de la Directive du module qui
  l'a introduite.
- **Organisation des fichiers** : un fichier par classe publique, désormais
  respecté aussi pour les widgets de l'écran de picking.
- **Conventions Flutter/Dart** : `analysis_options.yaml` (Module 1) respecté dans
  tout le code ajouté depuis.

---

## 9. Documentation technique — mise à jour

### Architecture finale (8 modules livrés)
```
core/                     Socle : config, erreurs, logs, thème, navigation,
                          session, stockage, synchronisation (structure)
features/
├── auth/                 Module 2 — Authentification, comptes
├── tours/                Module 3 — Téléchargement et gestion des tournées
├── picking/               Module 4 — Moteur de collecte
├── courier/                Module 5 — Produits introuvables, interface coursier
├── sync/                  Module 6 — Moteur de synchronisation réel
├── administration/         Module 8 — Tableau de bord, réassignation
└── user_management/        Module 2 — Gestion des comptes (UI)
```

### Dépendances (après nettoyage du Module 9)
`go_router`, `flutter_riverpod`, `drift` + `sqlite3_flutter_libs`, `path_provider`,
`path`, `flutter_secure_storage`, `connectivity_plus`, `uuid`, `crypto`, `logger` —
plus `flutter_lints`/`drift_dev`/`build_runner` en dépendances de développement.
`cupertino_icons` retirée.

### Migrations de la base locale (schéma final : v6)
| Version | Module | Ajout |
|---|---|---|
| v1 | 1 | `AppMetadataTable`, `SyncEventsTable` |
| v2 | 2 | `UsersTable` |
| v3 | 3 | `ToursTable`, `TourProductLinesTable` |
| v4 | 4 | `PickingProductStatusesTable` |
| v5 | 5 | `CourierRequestsTable` |
| v6 | 6 | Colonnes `priority`/`lastAttemptAt`/`lastError` sur `SyncEventsTable`, `SyncRunLogsTable` |

Le Module 9 n'ajoute aucune migration : tous les changements sont internes au code.

---

## 10. Changelog complet

Voir `CHANGELOG.md`, section "Module 9". Résumé :

**Corrections**
- Faille de contrôle d'accès par rôle au niveau du routeur.
- 8 écrans sans gestion d'erreur `FutureBuilder`.
- 3 forçages de non-nullité (`!`) sur la session, remplacés par des gardes
  défensives.

**Optimisations**
- N+1 requêtes éliminées dans `DriftProductRepository`.

**Nettoyage**
- Fichier mort supprimé (`TourProductLine`).
- Méthodes mortes supprimées (`SyncQueue.markAsSynced`/`markAsFailed`).
- Dépendance inutile retirée (`cupertino_icons`).
- `picking_screen.dart` éclaté en 4 fichiers.

**Dette technique restante**
1. Système d'internationalisation posé mais jamais branché.
2. Mot de passe administrateur par défaut codé en dur.
3. Aucun test de widget, d'intégration ou de navigation exécutable.
4. `SyncTransport` reste une simulation : aucun serveur réel n'existe encore.
5. `DriftCourierRepository.countOpenRequestsFor()` pourrait être optimisée en
   `COUNT` SQL si le volume augmentait significativement.

---

## 11. Limite technique constante depuis le Module 1

Cet environnement de conception ne dispose toujours pas du SDK Flutter/Dart :
`flutter analyze`, `flutter test` et `flutter run` n'ont pas pu être exécutés pour
valider mécaniquement cet audit. Chaque correction a été relue avec rigueur, mais
je le signale explicitement plutôt que de prétendre à une validation que je n'ai
pas pu effectuer.

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

---

## 12. Checklist complète — Module 9

- [ ] `flutter analyze` ne remonte aucune erreur ni avertissement.
- [ ] `flutter test` passe intégralement (≈87 cas attendus).
- [x] Aucun fichier mort restant identifié à l'audit.
- [x] Aucune dépendance inutile restante identifiée à l'audit.
- [x] Aucune fuite mémoire identifiée.
- [x] Chaque écran gère explicitement le cas d'erreur.
- [x] Le contrôle d'accès par rôle est appliqué au niveau du routeur.
- [x] Aucun mot de passe ni donnée sensible dans les journaux applicatifs.
- [ ] Vérification terrain : fermeture brutale pendant une collecte réelle.
- [ ] Vérification terrain : coupure réseau réelle pendant une synchronisation.
- [x] Documentation technique à jour dans ce document.
- [x] Changelog complet avec dette technique explicite.

**Fin du développement initial.** Comme convenu, la suite revient au terrain :
tests administrateur, préparateur, coursier, hors connexion, synchronisation,
multi-appareils, journée complète, charge — avant toute Version 1.1.
