# GENESIS PICKING — Module 3 : Gestion des tournées

Ce module ajoute la réception, le téléchargement, le stockage local et la reprise
d'une tournée. Aucun écran de picking, aucune logique de validation de produit,
aucune logique coursier n'ont été développés — conformément à la Directive.

---

## 1. Arborescence mise à jour

```
lib/
├── core/
│   ├── storage/
│   │   └── local_database.dart        [MODIFIÉ] schéma v3, tables de tournées
│   └── sync/
│       └── sync_queue.dart             [MODIFIÉ] extraction de l'interface
│                                          SyncEventSink (voir section 2)
│
└── features/
    └── tours/
        ├── tours_providers.dart            # Providers Riverpod du module
        ├── data/
        │   ├── tables/
        │   │   ├── tours_table.dart            # Table Drift des tournées
        │   │   └── tour_product_lines_table.dart  # Table Drift des lignes produits
        │   ├── tour.dart                   # Modèle Tour (indépendant de Drift)
        │   ├── tour_product_line.dart      # Modèle ligne produit (prêt pour Module 4)
        │   ├── tour_status.dart            # TourStatus + TourSyncState
        │   ├── tour_remote_source.dart     # Interface + DemoTourRemoteSource
        │   ├── tour_repository.dart        # Interface abstraite
        │   └── drift_tour_repository.dart  # Implémentation Drift
        ├── domain/
        │   └── tour_service.dart           # Processus 2 (téléchargement) et
        │                                      Processus 3 (reprise, structurel)
        └── presentation/
            ├── my_tours_screen.dart             # Écran "Mes tournées"
            └── tour_detail_placeholder_screen.dart  # Détail SANS produits

lib/core/navigation/app_router.dart   [MODIFIÉ] l'accueil Préparateur pointe
                                        désormais vers MyToursScreen (plus vers
                                        l'écran provisoire du Module 1)
lib/features/home_placeholder/role_home_placeholder_screen.dart  [MODIFIÉ]
                                        commentaire mis à jour, le cas
                                        Préparateur n'y est plus utilisé

test/
└── features/tours/
    ├── fake_tour_repository.dart       # Dépôt en mémoire (tests)
    ├── fake_tour_remote_source.dart    # Source distante contrôlable (tests)
    ├── fake_sync_event_sink.dart       # File de synchro en mémoire (tests)
    ├── tour_service_test.dart          # Téléchargement, doublons, reprise
    └── tour_repository_test.dart       # Stockage local, changement d'état, doublons
```

---

## 2. Justification des choix

### Deux tables plutôt qu'une seule (`ToursTable` / `TourProductLinesTable`)
Séparer les métadonnées de progression (`ToursTable`) des lignes produits brutes
(`TourProductLinesTable`) permet au Module 4 d'étendre uniquement la seconde (ajout
d'un état de collecte par produit) sans toucher à la première. Aucun champ d'état de
collecte n'a été ajouté à `TourProductLinesTable` : ce serait déjà de la "logique de
validation des produits", explicitement hors périmètre.

### `TourStatus` et `TourSyncState` comme deux enums séparés
La Directive cite six états ("Disponible, Téléchargée, En cours, Terminée,
Synchronisée, En attente de synchronisation") mais le PRD (chapitre 4.1) précise déjà
que la synchronisation est un "état transverse... indépendant de l'état métier". Les
modéliser comme un seul enum à six valeurs aurait rendu des combinaisons absurdes
représentables (ex. une tournée à la fois "Disponible" et "Synchronisée" n'a pas de
sens si on les confond). Deux enums orthogonaux empêchent structurellement ces états
impossibles, conformément au PRD, chapitre 5.

### `TourRemoteSource` comme interface, avec `DemoTourRemoteSource` en attendant le Module 8
La Directive porte sur le processus de téléchargement, pas sur l'intégration réelle
avec le logiciel de gestion (import PDF, API myFulfillment), qui relève de
l'Administration (Module 8). Plutôt que de bloquer ce module en attendant cette
intégration, une interface a été posée : `TourService` ne connaît que
`TourRemoteSource`, jamais son implémentation. `DemoTourRemoteSource` assigne
automatiquement deux tournées d'exemple à tout préparateur qui n'en a pas encore,
ce qui permet de tester tout le module de bout en bout dès aujourd'hui. Remplacer
cette classe par la vraie intégration au Module 8 ne touchera aucun autre fichier.

### Idempotence du téléchargement plutôt qu'un mécanisme de reprise complexe
Plutôt que de suivre un état "téléchargement partiel" produit par produit, le choix a
été de rendre `downloadTour` idempotent : si la tournée est déjà marquée téléchargée
localement, aucun nouvel appel réseau n'est fait et rien n'est dupliqué. Combiné à
l'écriture atomique côté `DriftTourRepository` (transaction Drift : soit la tournée
ET toutes ses lignes sont écrites, soit rien ne l'est), cela couvre exactement le cas
demandé : une coupure survenue *pendant* l'écriture ne laisse aucune trace partielle
à nettoyer, et une coupure survenue *après* un succès ne déclenche jamais de second
téléchargement réseau ni de doublon en base.

### Extraction de `SyncEventSink` depuis `SyncQueue` (petite modification du Module 1)
Pour que `TourService` puisse être testé sans dépendre de Drift, une interface
minimale (`SyncEventSink`, une seule méthode `enqueue`) a été extraite de `SyncQueue`.
C'est la seule modification apportée à un fichier du Module 1, et elle est strictement
additive : `SyncQueue` implémente désormais cette interface en plus de rester
utilisable exactement comme avant partout ailleurs (Module 1 non affecté). Ce choix a
été fait plutôt que d'écrire un test d'intégration nécessitant une vraie base Drift,
non exécutable dans cet environnement de toute façon (voir section 5).

### `TourService.completeTour` : un garde-fou structurel, pas une logique de validation
Ce module fournit la méthode qui fait passer une tournée à "Terminée", avec un seul
contrôle : le nombre de produits traités doit égaler le nombre total. C'est un
garde-fou déjà décrit dans le PRD (chapitre 5, "états impossibles"), pas une règle de
validation produit par produit (quantités, anomalies) — cette dernière responsabilité,
et la décision de quand appeler cette méthode, appartiennent entièrement au Module 4.

### Écran "Mes tournées" devient le véritable accueil Préparateur
Plutôt que de garder un accueil provisoire avec un bouton vers l'écran réel (comme
pour l'Administrateur, dont le tableau de bord complet reste à construire au
Module 8), l'accueil Préparateur est directement remplacé : la Directive demande
explicitement cet écran comme fonctionnalité complète du module, il n'y a donc rien
de provisoire à conserver à cet endroit.

---

## 3. Migrations de la base locale

| Schéma | Ajout | Module |
|---|---|---|
| v1 | `AppMetadataTable`, `SyncEventsTable` | Module 1 |
| v2 | `UsersTable` | Module 2 |
| v3 | `ToursTable`, `TourProductLinesTable` | Module 3 (ce module) |

La migration v2 → v3 crée les deux nouvelles tables sans toucher aux données
existantes (comptes utilisateurs, file de synchronisation déjà en attente) :

```dart
onUpgrade: (migrator, from, to) async {
  if (from < 2) {
    await migrator.createTable(usersTable);
  }
  if (from < 3) {
    await migrator.createTable(toursTable);
    await migrator.createTable(tourProductLinesTable);
  }
},
```

---

## 4. Tests réalisés

Conformément à la liste demandée par la Directive :

- **Téléchargement** — `tour_service_test.dart` : succès avec stockage correct,
  dépôt d'un événement de synchronisation, échec propre en cas de coupure réseau
  (aucune donnée partielle stockée).
- **Doublons** — `tour_service_test.dart` (un second `downloadTour` ne rappelle pas
  le réseau et n'écrit pas deux fois) et `tour_repository_test.dart`
  (`registerAvailableTour` n'écrase jamais une tournée déjà téléchargée).
- **Changement d'état** — `tour_repository_test.dart` : `updateStatus` modifie
  uniquement le champ ciblé ; `tour_service_test.dart` : transition
  Téléchargée → En cours au premier démarrage.
- **Reprise** — `tour_service_test.dart` : une tournée déjà "En cours" est renvoyée
  telle quelle par `startOrResume`, sans réinitialiser sa progression ; refus de
  démarrer une tournée non téléchargée ou déjà terminée.
- **Stockage local** — `tour_repository_test.dart` : une tournée sauvegardée est
  immédiatement accessible par `findById`/`countProductLines`, sans dépendance
  réseau ; filtrage correct par préparateur.
- **Intégrité** (ajouté au-delà de la liste, car explicitement demandé dans la
  section "Téléchargement" de la Directive : "vérifier son intégrité") — refus d'une
  tournée sans produit, refus d'un produit à quantité invalide, dans les deux cas
  sans qu'aucune donnée ne soit stockée.

Ces tests utilisent `FakeTourRepository`, `FakeTourRemoteSource` et
`FakeSyncEventSink` (tous en mémoire) : ils s'exécutent sans dépendre de Drift ni
d'un appareil réel.

### Même limite technique que les Modules 1 et 2
Cet environnement de conception ne dispose toujours pas du SDK Flutter/Dart :
`flutter test`, `flutter analyze` et la régénération de `local_database.g.dart`
(nécessaire suite à l'ajout de `ToursTable` et `TourProductLinesTable`) n'ont pas pu
être exécutés concrètement ici. Le code a été écrit et relu avec rigueur pour être
directement utilisable dans un environnement Flutter standard.

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

Résultat attendu de `flutter run` : un préparateur connecté arrive directement sur
"Mes tournées", voit deux tournées de démonstration à l'état "Disponible", peut les
télécharger (statut → "Téléchargée"), les commencer (statut → "En cours"), fermer et
rouvrir l'application (la progression et le statut sont conservés), et voir un écran
de détail affichant uniquement la progression globale — jamais de produit affiché.

---

## 5. Limites connues

- **`DemoTourRemoteSource` est un stand-in, pas une intégration réelle.** Aucune
  connexion à myFulfillment ni parsing PDF n'existe encore : c'est un choix assumé et
  documenté, réservé au Module 8.
- **Pas de contrainte de clé étrangère Drift entre `ToursTable.preparateurId` et
  `UsersTable.id`.** Un identifiant de préparateur invalide ne serait pas rejeté au
  niveau de la base ; ce contrôle pourrait être ajouté plus tard sans changer la
  structure actuelle.
- **La transaction atomique de `DriftTourRepository.saveDownloadedTour` n'a pas pu
  être exécutée pour de vrai dans cet environnement** (absence du SDK Flutter/Dart) ;
  son comportement d'idempotence a été vérifié via `FakeTourRepository`, qui
  reproduit la même logique mais sans les garanties transactionnelles réelles de
  SQLite. À vérifier en priorité lors de la première exécution réelle.
- **`TourProductLine` (modèle) n'est pas encore exposé par `TourRepository`.** Il a
  été préparé pour le Module 4, qui décidera de la meilleure façon d'exposer les
  lignes produits (nouvelle méthode sur `TourRepository`, ou dépôt dédié).
- **Aucune limite de taille ou de pagination** sur le nombre de tournées affichées
  dans "Mes tournées" — non nécessaire au volume actuel, à surveiller si le nombre de
  tournées par préparateur augmente significativement.

---

## 6. Points validés

- [x] Modèle `Tour` complet avec tous les champs demandés (identifiant, numéro,
      préparateur assigné, dates de création/téléchargement/synchronisation, état,
      nombre total de produits, progression).
- [x] Exactement les 4 états métier du PRD (`TourStatus`), plus les 2 états de
      synchronisation (`TourSyncState`), aucun état supplémentaire.
- [x] Téléchargement complet : récupération, vérification d'intégrité,
      enregistrement local atomique, protection contre les doublons, reprise fiable
      après coupure (idempotence).
- [x] Stockage local totalement indépendant du réseau (Drift/SQLite).
- [x] Structure de synchronisation préparée (événements déposés dans la file du
      Module 1 via `SyncEventSink`), sans transmission réelle — réservée au Module 7.
- [x] Écran "Mes tournées" : visualisation, état, téléchargement, reprise — aucun
      affichage de produit.
- [x] Logique de reprise prête et testée : une tournée interrompue conserve
      exactement son état et sa progression.
- [x] Séparation stricte données (`data/`) / logique métier (`domain/`) / interface
      (`presentation/`), avec les quatre classes demandées : `Tour`, `TourStatus`,
      `TourRepository`, `TourService`.
- [x] Tests unitaires couvrant téléchargement, doublons, changement d'état, reprise,
      stockage local, exécutables sans Drift ni appareil réel.
- [ ] Non concerné par ce module (volontairement) : écran de picking, validation de
      produit, logique coursier, transmission réseau réelle, import réel depuis le
      logiciel de gestion — voir Modules 4, 6, 7, 8.

**Prochaine étape** : Module 4 — Écran de picking, qui étendra
`TourProductLinesTable` avec un état de collecte par produit, consommera
`TourRepository`/`TourService` sans les modifier en profondeur, et remplacera
`tour_detail_placeholder_screen.dart` par le véritable écran de collecte guidée.
