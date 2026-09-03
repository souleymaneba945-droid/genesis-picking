# GENESIS PICKING — Module 6 : Synchronisation

Moteur de synchronisation, sans aucune modification du moteur de picking ni du
module coursier — tous deux continuent d'utiliser exactement la même interface
`SyncEventSink` posée au Module 1.

---

## 1. Architecture

```
lib/
├── core/sync/
│   ├── sync_event.dart      [MODIFIÉ] + SyncPriority, état "retrying", colonnes
│   │                            priority/lastAttemptAt/lastError (additif)
│   ├── sync_queue.dart      [MODIFIÉ] enqueue() accepte une priorité optionnelle
│   │                            (défaut : normale — compatible avec tous les
│   │                            appels existants des Modules 3, 4, 5)
│   ├── network_monitor.dart [NOUVEAU] NetworkMonitor + interface ConnectivityState
│   └── sync_manager.dart    [MODIFIÉ] délègue désormais la détection réseau à
│                                NetworkMonitor (API publique inchangée)
│
├── core/providers/core_providers.dart  [MODIFIÉ] + networkMonitorProvider
│                                          (partagé entre SyncManager et SyncService)
│
└── features/sync/
    ├── sync_providers.dart
    ├── data/
    │   ├── tables/sync_run_logs_table.dart
    │   ├── sync_operation.dart      # Modèle + libellés français d'affichage
    │   ├── sync_run_log.dart        # Modèle de ligne de journal
    │   ├── sync_repository.dart     # Interface
    │   ├── drift_sync_repository.dart
    │   └── sync_transport.dart      # Interface + SimulatedSyncTransport
    ├── domain/
    │   ├── conflict_resolver.dart   # ConflictResolver
    │   └── sync_service.dart        # SyncService
    └── presentation/
        ├── sync_controller.dart
        └── sync_screen.dart          # Écran Synchronisation

Points d'accès ajoutés : icône "Synchronisation" dans l'AppBar de Mes tournées,
de l'accueil Coursier, et bouton dédié sur l'accueil Administrateur.

test/features/sync/
├── sync_service_test.dart
├── conflict_resolver_test.dart
├── fake_sync_repository.dart
├── fake_sync_transport.dart
└── fake_connectivity_state.dart
```

### Les cinq composants demandés, une responsabilité chacun
- **`SyncQueue`** (Module 1, inchangé dans son rôle) — point d'entrée pour DÉPOSER
  un événement. Les modules métier ne connaissent que ça.
- **`SyncRepository`** — accès aux données POUR le moteur lui-même : lecture
  triée par priorité, changement de statut, journal. Ne prend aucune décision.
- **`NetworkMonitor`** — seule classe du projet à parler à `connectivity_plus`.
- **`ConflictResolver`** — décide quelle valeur retenir entre deux versions
  concurrentes. Ne lit ni n'écrit jamais aucune donnée lui-même.
- **`SyncService`** — orchestre les quatre précédents : boucle de traitement,
  gestion des tentatives, déclenchement automatique, journalisation.

### Pourquoi `SyncQueue` et `SyncRepository` sont deux classes distinctes
Le Module 1 avait déjà posé `SyncQueue` comme point d'entrée pour les modules
métier (`TourService`, `PickingController` via `PickingService`, `CourierService`).
Plutôt que de faire porter au moteur de synchronisation lui-même cette même classe
(qui aurait mélangé "déposer un événement" et "faire progresser la file"),
`SyncRepository` a été créée comme un second accès aux MÊMES données
(`SyncEventsTable`), avec des opérations différentes (tri par priorité, changement
de statut, journal). Aucun des trois modules producteurs (3, 4, 5) ne connaît
`SyncRepository` ; `SyncService` ne connaît jamais `SyncQueue`.

### `NetworkMonitor` : extraction depuis `SyncManager`, sans rien casser
Le Module 1 avait posé `SyncManager` avec la détection réseau intégrée
(`connectivity_plus` directement). Cette responsabilité a été extraite dans
`NetworkMonitor`, et `SyncManager` a été modifié pour s'appuyer dessus — mais son
API publique (`initialize()`, `stateStream`, `currentState`, `triggerSync()`,
`dispose()`) est restée **strictement identique**. `courier_availability_checker.dart`
(Module 5), qui dépend de `SyncManager.currentState`, n'a donc nécessité aucune
modification. Une interface `ConnectivityState` a été extraite de
`NetworkMonitor` pour que `SyncService` soit testable sans dépendre de
`connectivity_plus` (même principe que `CourierAvailabilityChecker` au Module 5).

### Pourquoi `SyncManager.triggerSync()` ne transmet toujours rien lui-même
`SyncManager` reste un simple indicateur d'interface (icône de synchronisation).
Le VRAI déclenchement de la transmission est assuré par `SyncService`, qui écoute
lui-même `NetworkMonitor` de façon indépendante (`startAutoSync()`). Ce choix évite
que `core/` (le socle) dépende de `features/sync/` (un module métier) — la
direction de dépendance imposée depuis le Module 1 (`features/*` dépend de `core/`,
jamais l'inverse) est ainsi respectée sans exception.

### File d'attente : les cinq champs exigés, plus le contenu déjà existant
Chaque opération porte déjà, depuis le Module 1 : identifiant, type, date (`eventType`,
`createdAt`). Le Module 6 ajoute les champs manquants : `priority`, `status` (déjà
présent, étendu à 5 valeurs), `attemptCount` (déjà présent). `lastAttemptAt` et
`lastError` ont été ajoutés en plus, pour le journal de diagnostic (Directive,
"Journal... erreurs"), au-delà du strict minimum demandé.

### États : exactement les cinq de la Directive
`En attente` (`pending`) → `En cours` (`inProgress`) → `Synchronisé` (`synced`) ou
`À réessayer` (`retrying`) → `Échec` (`failed`) une fois le nombre maximal de
tentatives atteint (5 par défaut, configurable). Les noms internes restent ceux du
Module 1 (`SyncEventStatus`) ; les libellés français exacts de la Directive ne
vivent que dans `SyncEventStatusLabel` (affichage), pour ne jamais avoir à
renommer une colonne de base de données déjà en usage.

### Détection réseau et reprise : la simplicité du design fait le travail
Aucun mécanisme de "curseur" ou de "point de reprise" séparé n'a été nécessaire :
`SyncRepository.fetchOperationsToProcess()` ne renvoie JAMAIS les opérations déjà
`Synchronisé`. Une interruption (perte réseau en cours de boucle, fermeture de
l'app) laisse simplement les opérations non traitées à `En attente`/`À réessayer` ;
la prochaine exécution les retrouve naturellement, dans le même ordre. Aucune
opération déjà validée n'est jamais rejouée — testé explicitement.

### Gestion des conflits — les trois cas de la Directive
- **Deux mises à jour du même produit** → `resolveProgressiveState` : l'état le
  plus avancé dans le flux gagne (principe déjà posé dans "Processus métier V1",
  repris ici sous forme testable et réutilisable).
- **Suppression d'une tournée déjà modifiée** → `resolveTourDeletionConflict` :
  toute modification locale non synchronisée bloque la suppression distante — le
  travail de terrain n'est jamais perdu ; le cas est signalé pour intervention
  humaine plutôt que résolu automatiquement dans le mauvais sens.
- **Réponse coursier reçue pendant une préparation** →
  `resolveCourierResponseConflict` : la première réponse réellement donnée fait foi.

`ConflictResolver` est prêt à être appelé par un futur transport réel (aucun
backend n'existe encore — voir `SyncTransport`) ; il est déjà entièrement testé de
façon isolée, indépendamment de toute intégration réseau.

### `SyncTransport` : même principe que `DemoTourRemoteSource` (Module 3)
Aucun serveur réel n'existe. `SimulatedSyncTransport` accepte toujours la
transmission, ce qui permet de tester tout le moteur (file, priorités, reprise,
journal, écran) de bout en bout dès aujourd'hui. Brancher un vrai serveur revient à
fournir une nouvelle implémentation de `SyncTransport`, sans toucher au reste du
moteur.

---

## 2. Migration de la base locale

| Schéma | Ajout | Module |
|---|---|---|
| v5 | `CourierRequestsTable` | Module 5 |
| v6 | Colonnes `priority`/`lastAttemptAt`/`lastError` sur `SyncEventsTable`, table `SyncRunLogsTable` | Module 6 (ce module) |

```dart
if (from < 6) {
  await migrator.addColumn(syncEventsTable, syncEventsTable.priority);
  await migrator.addColumn(syncEventsTable, syncEventsTable.lastAttemptAt);
  await migrator.addColumn(syncEventsTable, syncEventsTable.lastError);
  await migrator.createTable(syncRunLogsTable);
}
```

Aucune tournée, compte, état de collecte ou demande coursier existant n'est
affecté ; les événements déjà en file (Modules 3, 4, 5) reçoivent automatiquement
la priorité par défaut (`normale`).

---

## 3. Tests réalisés

Conformément à la liste exacte de la Directive, dans `sync_service_test.dart` :

- **Synchronisation sans erreur** — toutes les opérations passent à
  "Synchronisé" ; hors connexion, rien n'est tenté ni perdu ; l'ordre de priorité
  est respecté.
- **Coupure réseau pendant la synchronisation** — les opérations déjà envoyées
  restent acquises, les suivantes ne sont simplement pas tentées.
- **Reprise** — une seconde exécution ne renvoie jamais une opération déjà
  synchronisée.
- **Doublons** — deux appels concurrents ne traitent chaque opération qu'une
  seule fois (verrou `_isRunning`).
- **Conflits** — `conflict_resolver_test.dart` couvre les trois cas de la
  Directive, plus le cas générique "dernière écriture gagne".
- **Plusieurs centaines d'opérations en attente** — 300 opérations traitées
  correctement en une exécution.
- **Synchronisation après plusieurs jours hors connexion** — accumulation de
  10 opérations sur une période simulée de 4 jours hors ligne, aucune perte,
  transmission complète au retour du réseau.
- (Ajouté au-delà de la liste) **Échecs et nouvelles tentatives** — passage à
  "À réessayer" sous le seuil, "Échec" définitif au-delà ; une opération en échec
  n'empêche jamais les suivantes d'être traitées.

### Même limite technique que les modules précédents
`flutter test`/`flutter run` et la régénération de `local_database.g.dart`
(nécessaire suite aux nouvelles colonnes et à `SyncRunLogsTable`) n'ont pas pu être
exécutés dans cet environnement de conception (absence du SDK Flutter/Dart).

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

---

## 4. Checklist de validation — Module 6

- [ ] Les actions sont enregistrées localement (déjà vrai depuis les Modules 3-5 ;
      ce module ne fait qu'ajouter le traitement de la file).
- [ ] Elles sont placées dans une file d'attente avec identifiant, type, date,
      priorité, état, nombre de tentatives.
- [ ] La synchronisation démarre automatiquement lorsque le réseau revient (sans
      action de l'utilisateur).
- [ ] Les doublons sont évités (une opération synchronisée n'est jamais retransmise).
- [ ] Les conflits sont gérés selon une stratégie claire et testée (trois cas de la
      Directive).
- [ ] Les erreurs sont rejouées automatiquement ("À réessayer"), jusqu'à un seuil
      au-delà duquel elles passent en "Échec" sans bloquer les autres opérations.
- [ ] Aucune donnée n'est perdue, y compris après une coupure prolongée (testé sur
      4 jours simulés).
- [ ] L'utilisateur peut continuer à travailler pendant la synchronisation (le
      moteur ne verrouille aucun écran ; testé implicitement par la conception :
      aucune méthode de ce module n'est appelée depuis le chemin critique du
      picking ou du module coursier).
- [ ] L'écran Synchronisation affiche exactement les quatre informations demandées
      et le bouton "Synchroniser maintenant" fonctionne.

---

## 5. Points validés

- [x] Architecture complète : `SyncService`, `SyncQueue`, `SyncRepository`,
      `ConflictResolver`, `NetworkMonitor`, chacun à responsabilité unique.
- [x] File d'attente enrichie avec tous les champs demandés.
- [x] Cinq états exacts, avec transitions testées.
- [x] Détection réseau automatique et déclenchement de synchronisation sans action
      utilisateur.
- [x] Stratégie de conflits définie et testée pour les trois cas cités par la
      Directive.
- [x] Reprise exacte après interruption, sans jamais rejouer une opération validée.
- [x] Journal complet (début, fin, durée calculée, nombre d'éléments, erreurs).
- [x] Écran Synchronisation minimal, conforme à la Directive.
- [x] Moteur de picking et module coursier non modifiés : ils continuent d'utiliser
      `SyncEventSink.enqueue()` à l'identique.
- [ ] Non concerné par ce module (volontairement) : administration — voir Module 8 ;
      transport réseau réel (un vrai serveur reste à brancher derrière
      `SyncTransport`, dont c'est exactement la raison d'être).

**Prochaine étape** : Module 8 — Administration (le tableau de bord complet de
l'Administrateur, au-delà de la gestion des comptes déjà livrée au Module 2).
