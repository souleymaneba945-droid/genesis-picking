# GENESIS PICKING — Module 5 : Gestion des produits introuvables & Coursiers

Ajoute la gestion des produits introuvables et l'interface coursier, sans modifier
le moteur de picking, sans développer l'administration ni les statistiques.

---

## 1. Architecture

```
lib/
├── core/storage/local_database.dart   [MODIFIÉ] schéma v5, table des demandes
│
├── features/
│   ├── picking/
│   │   └── presentation/
│   │       ├── picking_controller.dart   [MODIFIÉ] + marquerEnvoyeAuCoursier()
│   │       │                                (additif — aucune méthode existante
│   │       │                                 touchée, PickingService inchangé)
│   │       └── picking_screen.dart       [MODIFIÉ] "Introuvable" ouvre désormais
│   │                                        l'écran de choix du coursier
│   │
│   └── courier/
│       ├── courier_providers.dart
│       ├── data/
│       │   ├── tables/courier_requests_table.dart
│       │   ├── courier_request_status.dart   # CourierRequestStatus, CourierRequestResult
│       │   ├── courier_request.dart          # Modèle CourierRequest
│       │   ├── courier_summary.dart          # Vue "choix du coursier"
│       │   ├── courier_request_detail_view.dart  # Vue "traitement coursier"
│       │   ├── courier_availability_checker.dart # Interface + impl réelle
│       │   ├── courier_repository.dart       # Interface
│       │   └── drift_courier_repository.dart
│       ├── domain/
│       │   └── courier_service.dart          # Toute la logique métier
│       └── presentation/
│           ├── courier_controller.dart       # Liste des demandes du coursier
│           ├── courier_selection_screen.dart # Choix du coursier (préparateur)
│           ├── courier_home_screen.dart      # Accueil coursier
│           ├── courier_request_detail_screen.dart  # Traitement (coursier)
│           └── my_courier_requests_screen.dart     # Retour préparateur

lib/core/navigation/app_router.dart  [MODIFIÉ] accueil Coursier → CourierHomeScreen
lib/features/home_placeholder/role_home_placeholder_screen.dart  [MODIFIÉ] doc

test/features/courier/
├── courier_service_test.dart
├── fake_courier_repository.dart
├── fake_product_repository.dart
└── fake_availability_checker.dart
```

### Les quatre classes demandées
- **`CourierRequest`** — modèle de données pur, exactement les champs exigés
  (identifiant, préparateur, coursier, tournée, produit, quantité, emplacement,
  date/heure, état) plus les horodatages d'historique.
- **`CourierRepository`** / **`DriftCourierRepository`** — accès aux données, aucune
  règle métier.
- **`CourierService`** — toute la logique métier : qui peut voir quoi, quelles
  transitions sont permises, quand la synchronisation ultérieure se déclenche.
- **`CourierController`** — état d'écran (Riverpod `AsyncNotifier`) pour la liste des
  demandes du coursier connecté ; délègue entièrement à `CourierService`.

### "Ne pas modifier le moteur de picking" — comment c'est respecté
`PickingService` n'a reçu **aucune modification**. La seule touche au Module 4 est
l'ajout d'une nouvelle méthode à `PickingController`
(`marquerEnvoyeAuCoursier(productLineId)`), strictement additive : elle appelle la
méthode générique déjà existante `PickingService.validateCurrentProduct` (qui
acceptait déjà n'importe quel `ProductState` en paramètre depuis le Module 4) avec
`ProductState.envoyeAuCoursier` — un état déjà défini par la Directive du Module 4
mais volontairement inatteignable jusqu'ici. Aucune règle de validation, aucune
transition existante n'a été changée.

### Séquence exacte "Introuvable" → demande créée
1. Le préparateur appuie sur "Introuvable" dans `PickingScreen` : le produit passe
   immédiatement à `ProductState.introuvable` (mécanisme du Module 4, inchangé) et
   la session avance au produit suivant.
2. L'écran `CourierSelectionScreen` s'ouvre, avec le produit **capturé avant**
   l'avancement de la session (sinon l'information serait perdue).
3. Le préparateur choisit un coursier : validation immédiate, sans confirmation
   supplémentaire.
   - La demande est créée (`CourierService.createRequest`).
   - Puis, seulement si la création réussit, le produit passe à
     `ProductState.envoyeAuCoursier` via `marquerEnvoyeAuCoursier` — cet ordre évite
     qu'un produit reste marqué "envoyé" sans demande associée en cas d'échec.
4. Retour automatique à `PickingScreen`, déjà positionné sur le produit suivant.

Si le préparateur annule l'écran de choix sans sélectionner de coursier, le produit
reste à l'état `introuvable` — un état déjà considéré "traité" par le Module 4, donc
sans effet sur la progression. C'est un choix assumé : la Directive n'impose pas de
retour manuel, donc aucune action de correction n'est proposée à ce stade.

### États et transitions des demandes
Exactement les six états de la Directive : `Créée → (En attente | Reçue) →
Acceptée → Traitée → Terminée`.

- **Créée → En attente / Reçue** : décidé immédiatement à la création, selon
  `CourierAvailabilityChecker.isOnline` (voir ci-dessous).
- **En attente → Reçue** : dès que le coursier consulte sa liste de demandes alors
  que l'appareil est de nouveau en ligne — c'est le mécanisme de "synchronisation
  ultérieure" exigé par la Directive.
- **Reçue/En attente → Acceptée** : au moment où le coursier ouvre le détail de la
  demande (`CourierService.openRequest`) — l'ouverture EST l'acceptation, aucune
  étape supplémentaire n'a été ajoutée, conformément à "il visualise... puis il
  choisit", sans bouton "Accepter" distinct.
- **Acceptée → Traitée** : au moment de la réponse (retrouvé/non retrouvé).
- **Traitée → Terminée** : dès que le préparateur consulte ses demandes
  (`listRequestsForPreparateur`) — matérialise "le préparateur reçoit immédiatement
  la mise à jour". Simplification assumée et documentée : dans un contexte
  multi-appareils réel, cette clôture attendrait la confirmation de synchronisation
  (Module 7) ; ici, base locale partagée entre rôles, donc immédiat.

### `CourierAvailabilityChecker` — pourquoi une nouvelle interface plutôt que d'utiliser directement `SyncManager`
Le `SyncManager` (Module 1) suit déjà l'état réseau ; `SyncManagerAvailabilityChecker`
n'en est qu'un mince wrapper (`currentState != SyncState.offline`). L'interface a
été extraite pour permettre un remplacement entièrement contrôlable dans les tests
(`FakeCourierAvailabilityChecker`), sans dépendre de `connectivity_plus` ni de Drift.
Aucune modification du `SyncManager` lui-même n'a été nécessaire.

### "Priorité" du coursier : calculée, pas stockée
La Directive demande d'afficher "leur priorité" dans la liste du coursier. Plutôt que
d'ajouter une colonne, la priorité est simplement le rang dans la liste triée par
date de création croissante (la plus ancienne = priorité 1) — évite un champ
redondant qui pourrait diverger de l'ordre réel.

### Ce que le coursier NE voit PAS dans la liste
Conformément à "aucune autre information" : la liste (`CourierHomeScreen`) n'affiche
que le rang et l'état. Le nom du produit, l'image, la quantité, l'emplacement et le
nom du préparateur n'apparaissent que dans l'écran de détail
(`CourierRequestDetailScreen`), une fois la demande ouverte.

### Dénormalisation volontaire (quantité, emplacement) sur `CourierRequestsTable`
Comme documenté directement dans la table : ces champs sont dupliqués depuis
`TourProductLinesTable` au moment de la création, pour que l'historique d'une
demande reste exact même si la ligne produit d'origine changeait par ailleurs.

---

## 2. Migration de la base locale

| Schéma | Ajout | Module |
|---|---|---|
| v4 | `PickingProductStatusesTable` | Module 4 |
| v5 | `CourierRequestsTable` | Module 5 (ce module) |

```dart
if (from < 5) {
  await migrator.createTable(courierRequestsTable);
}
```

Aucune tournée, compte ou état de collecte existant n'est affecté.

---

## 3. Tests réalisés

Conformément à la liste de la Directive, tous dans `courier_service_test.dart` :

- **Création d'une demande** — tous les champs requis sont bien renseignés.
- **Choix du coursier** — seuls les coursiers actifs apparaissent, avec leur charge
  ouverte correcte ; un coursier désactivé disparaît de la liste.
- **Réception** — une demande "En attente" devient "Reçue" dès que le coursier
  consulte sa liste alors que l'appareil est en ligne.
- **Validation** — répondre "Produit retrouvé"/"Non retrouvé" fait passer la
  demande à "Traitée" ; refus de répondre à une demande non encore acceptée.
- **Retour préparateur** — une demande "Traitée" devient "Terminée" dès consultation
  par le préparateur, avec le résultat correctement rapporté.
- **Reprise après fermeture** — un nouveau `CourierService` reconstruit sur le même
  dépôt retrouve exactement les demandes déjà créées.
- **Fonctionnement hors connexion** — création hors connexion → "En attente" ;
  création en ligne → "Reçue" directement ; retour en ligne → transition automatique
  vérifiée explicitement.

### Même limite technique que les modules précédents
`flutter test`/`flutter run` et la régénération de `local_database.g.dart`
(nécessaire suite à l'ajout de `CourierRequestsTable`) n'ont pas pu être exécutés
dans cet environnement de conception (absence du SDK Flutter/Dart).

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

---

## 4. Checklist de validation — Module 5

- [ ] Le préparateur peut signaler un produit introuvable depuis l'écran de picking.
- [ ] Il peut choisir un coursier parmi les coursiers actifs uniquement, avec leur
      nombre de demandes en attente affiché.
- [ ] Une demande est créée avec tous les champs requis (identifiant, préparateur,
      coursier, tournée, produit, quantité, emplacement, date, heure, état).
- [ ] Le coursier voit uniquement ses demandes (jamais celles d'un autre coursier),
      avec leur priorité et leur état — aucune autre information dans la liste.
- [ ] Il peut ouvrir une demande et voir photo, nom, quantité, emplacement,
      préparateur demandeur.
- [ ] Il peut répondre « Produit retrouvé ».
- [ ] Il peut répondre « Produit non retrouvé ».
- [ ] Le préparateur reçoit correctement le résultat dans "Mes demandes coursier".
- [ ] Une demande créée hors connexion reste fonctionnelle et se met à jour dès le
      retour du réseau (testé : "En attente" → "Reçue").
- [ ] Toutes les actions (création, ouverture, réponse, consultation préparateur)
      sont enregistrées localement, avec leurs horodatages.

---

## 5. Points validés

- [x] Logique métier complète des produits introuvables, du signalement à la
      création automatique de la demande.
- [x] Écran de choix du coursier : coursiers actifs uniquement, nom + charge
      ouverte, validation immédiate.
- [x] Demande complète avec tous les champs exigés par la Directive.
- [x] Exactement les six états de demande, aucun autre.
- [x] Interface coursier dédiée, limitée à ses propres demandes.
- [x] Écran de traitement : photo, nom, quantité, emplacement, préparateur
      demandeur ; exactement deux choix.
- [x] Retour préparateur automatique, sans action manuelle de sa part au-delà de
      consulter l'écran dédié.
- [x] Historique complet : création, acceptation, traitement, clôture, toutes
      les dates et heures.
- [x] Architecture complète : `CourierRequest`, `CourierRepository`,
      `CourierService`, `CourierController`, séparation stricte
      données/logique/interface.
- [x] Moteur de picking non modifié (une seule méthode additive sur son
      contrôleur, zéro changement sur `PickingService`).
- [ ] Non concerné par ce module (volontairement) : administration, statistiques,
      transmission réseau réelle des événements coursier — voir Modules 7, 8.

**Prochaine étape** : Module 6 (selon le plan initial, ce module correspondait déjà
à l'interface coursier — désormais livrée ici). La suite logique est le Module 7 —
Synchronisation, qui donnera un traitement réel aux événements déjà déposés dans la
file du Module 1 par ce module et les précédents.
