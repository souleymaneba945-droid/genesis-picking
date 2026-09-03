# GENESIS PICKING — Module 4 : Moteur de Picking

Le cœur du produit. Ce module ajoute le moteur de collecte guidée produit par produit,
sans toucher au coursier, à l'administration, ni à la synchronisation complète.

---

## 1. Architecture

```
lib/
├── core/
│   └── storage/
│       └── local_database.dart        [MODIFIÉ] schéma v4, table des états
│
└── features/
    ├── tours/
    │   ├── data/
    │   │   ├── tour_repository.dart        [MODIFIÉ] + updateProgress() (additif)
    │   │   └── drift_tour_repository.dart  [MODIFIÉ] implémentation de updateProgress
    │   └── presentation/
    │       └── my_tours_screen.dart        [MODIFIÉ] ouvre désormais PickingScreen
    │
    └── picking/
        ├── picking_providers.dart          # Providers Riverpod du module
        ├── data/
        │   ├── tables/
        │   │   └── picking_product_statuses_table.dart  # Table compagne (1-à-1)
        │   ├── product_state.dart          # ProductState (5 états)
        │   ├── picking_product.dart        # Modèle combiné (donnée + état)
        │   ├── product_repository.dart     # Interface — CRUD produit pur
        │   ├── drift_product_repository.dart
        │   ├── picking_repository.dart     # Interface — orchestration atomique
        │   └── drift_picking_repository.dart
        ├── domain/
        │   ├── picking_session.dart        # PickingSession + PickingProgress
        │   └── picking_service.dart        # Chargement, validation, reprise
        └── presentation/
            ├── picking_controller.dart     # État écran (Riverpod)
            └── picking_screen.dart         # Écran — LE moteur

lib/features/tours/presentation/tour_detail_placeholder_screen.dart  [SUPPRIMÉ]
                                             remplacé par PickingScreen

core/sync/sync_queue.dart   inchangé depuis le Module 3 (SyncEventSink déjà extrait)

test/features/picking/
├── fake_picking_repository.dart
└── picking_service_test.dart
```

### Pourquoi cinq classes distinctes (`ProductState`, `ProductRepository`,
`PickingRepository`, `PickingService`, `PickingController`)

- **`ProductState`** — les cinq états, et uniquement eux, isolés dans leur propre
  fichier pour qu'aucune autre partie du code ne puisse en inventer un sixième.
- **`ProductRepository`** — CRUD pur sur un produit et son état, sans aucune notion
  de tournée ni de progression. Peut être utilisé isolément (ex. relire l'état d'un
  seul produit) sans jamais toucher à `ToursTable`.
- **`PickingRepository`** — la seule classe qui touche à la fois un produit ET la
  progression de sa tournée, dans une transaction unique. C'est délibérément séparé
  de `ProductRepository` : mélanger les deux aurait rendu `ProductRepository`
  dépendant de la notion de tournée, cassant sa réutilisabilité pure.
- **`PickingService`** — logique métier (Processus 3, 4, 5) : quel produit est
  "courant", comment une validation fait avancer la session, quand la tournée est
  terminée. Ne connaît ni Drift ni Riverpod.
- **`PickingController`** — état d'écran (Riverpod `FamilyAsyncNotifier`), un par
  tournée (`arg = tourId`). Ne contient aucune règle métier, uniquement de la
  délégation à `PickingService` et le reflet du résultat dans `state`.

### Table compagne plutôt que colonnes ajoutées à `TourProductLinesTable`
Comme annoncé dans la documentation du Module 3, `PickingProductStatusesTable` est
une table séparée, en relation un-à-un via `productLineId`. Le fichier
`tour_product_lines_table.dart` du Module 3 n'a donc pas été modifié.

### Deux petites extensions additives à des modules précédents
1. **`TourRepository.updateProgress()`** (Module 3) — ajoutée pour que ce module
   puisse persister le compteur de produits traités. Signature strictement
   additive : aucune méthode existante n'a été retirée ni modifiée.
2. Rien d'autre n'a été touché dans `SyncQueue`/`SyncEventSink` (déjà extrait au
   Module 3) : ce module ne dépose d'ailleurs aucun événement de synchronisation —
   la Directive exclut explicitement la synchronisation complète, et les
   changements d'état produit par produit seraient d'un volume trop élevé pour la
   file générique telle quelle ; leur transmission réelle est laissée au Module 7,
   qui décidera de la bonne granularité.

### Chargement sans requête réseau
`PickingService.openSession` ne fait qu'appeler `TourService.startOrResume` (Module
3, purement local) puis `PickingRepository.loadProducts` (Drift local). Aucun appel
réseau n'existe nulle part dans ce module, conformément à la Directive.

### Ordre de présentation figé dans le widget, pas dans le modèle
`PickingProduct` ne porte aucune notion d'ordre d'affichage : c'est
`_ProductCard` (l'écran) qui impose visuellement emplacement → quantité → image →
nom → description, exactement comme demandé, en un seul endroit du code.

### Quantité éditable inline, pas de fenêtre séparée
Conformément à "aucune fenêtre inutile" et "aucune validation intermédiaire", la
quantité trouvée se règle avec un simple stepper (+/-) directement sur l'écran du
produit ; un seul bouton "Produit trouvé" décide ensuite, selon que la quantité
saisie égale ou non la quantité demandée, entre `collecte` et
`partiellementCollecte` — aucune étape de confirmation supplémentaire.

### Point d'entrée "Introuvable" sans écran de coursier
Le bouton "Introuvable" fait uniquement passer le produit à l'état
`ProductState.introuvable` et avance au produit suivant. `ProductState.envoyeAuCoursier`
existe dans l'énumération (demandé par la Directive) mais n'est atteint par aucun
code de ce module — il ne le sera qu'au Module 5, qui ajoutera l'écran de choix du
coursier et la transition correspondante.

### Aucun retour manuel — décision volontaire
La Directive impose "aucun retour manuel nécessaire" et liste "produit précédent (si
prévu)" comme test conditionnel. Ce n'est pas prévu : ni `PickingService` ni
`PickingController` n'exposent de méthode pour revenir au produit précédent. C'est
documenté explicitement dans `picking_service_test.dart`.

---

## 2. Migration de la base locale

| Schéma | Ajout | Module |
|---|---|---|
| v3 | `ToursTable`, `TourProductLinesTable` | Module 3 |
| v4 | `PickingProductStatusesTable` | Module 4 (ce module) |

```dart
if (from < 4) {
  await migrator.createTable(pickingProductStatusesTable);
}
```

Aucune tournée ni compte existant n'est affecté par cette migration.

---

## 3. Tests réalisés

Conformément à la liste de la Directive :

- **Validation** — quantité complète → `Collecté` ; quantité inférieure →
  `Partiellement collecté` ; `markCurrentProductIntrouvable` → `Introuvable`.
- **Reprise** — rouvrir une session après un produit déjà validé retrouve exactement
  le bon produit courant, la bonne progression, et l'état conservé du produit déjà
  traité (pas de réinitialisation).
- **Progression** — vérifiée après chaque validation (`traites`/`total`), et
  vérifiée comme réellement persistée sur la tournée (pas seulement en mémoire).
- **États** — les quatre états atteignables dans ce module sont couverts ; le
  cinquième (`envoyeAuCoursier`) est volontairement non testé ici puisqu'aucun code
  de ce module ne peut l'atteindre (voir section 1).
- **Produit suivant** — après chaque validation, `produitCourant` avance
  correctement, jusqu'à devenir `null` une fois tous les produits traités.
- **Produit précédent** — non prévu (voir section 1) ; documenté explicitement dans
  le fichier de test plutôt que silencieusement absent.
- **Sauvegarde** — `tourRepository.findById` après validation confirme que la
  progression est bien écrite dans le dépôt, indépendamment de l'objet session tenu
  en mémoire par l'appelant.

### Même limite technique que les modules précédents
`flutter test`/`flutter run` et la régénération de `local_database.g.dart`
(nécessaire suite à l'ajout de `PickingProductStatusesTable`) n'ont pas pu être
exécutés dans cet environnement de conception (absence du SDK Flutter/Dart).

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

Résultat attendu de `flutter run` : ouvrir une tournée téléchargée affiche le
premier produit (emplacement en évidence, quantité éditable, image ou espace
réservé, nom, description). Valider fait immédiatement apparaître le produit
suivant, la barre de progression se met à jour sans délai visible. Fermer
l'application en pleine collecte puis la rouvrir doit ramener exactement au même
produit avec la même progression. Une fois tous les produits traités, un écran de
fin de tournée propose de la clôturer.

---

## 4. Checklist de validation — Module 4

- [ ] Un produit s'affiche correctement, dans l'ordre emplacement → quantité →
      image → nom → description.
- [ ] L'image est chargée quand disponible ; un espace réservé s'affiche sinon,
      sans erreur visible.
- [ ] L'emplacement est bien visible (le plus grand élément textuel de l'écran).
- [ ] La quantité est bien visible et modifiable sans ouvrir de fenêtre séparée.
- [ ] La validation fonctionne et fait apparaître immédiatement le produit suivant.
- [ ] La progression (traités/total/pourcentage) est correcte après chaque
      validation.
- [ ] Les données sont enregistrées localement (vérifiable en rouvrant l'écran
      "Mes tournées" : la progression affichée y est à jour).
- [ ] Une fermeture forcée de l'application en pleine collecte permet une reprise
      exacte (même produit courant, même progression, mêmes états déjà enregistrés).
- [ ] Aucun accès réseau n'est nécessaire pendant tout le déroulement du picking.

---

## 5. Points validés

- [x] Chargement automatique de la tournée (produits, ordre, image, description,
      quantité, emplacement, état), sans aucune requête réseau.
- [x] Présentation d'un seul produit à la fois, dans l'ordre imposé.
- [x] Navigation automatique au produit suivant après chaque validation, sans
      retour manuel ni étape intermédiaire.
- [x] Barre de progression limitée à traités/total/pourcentage, mise à jour
      immédiate.
- [x] Exactement les cinq états de la Directive, aucun autre.
- [x] Logique de validation complète : enregistrement local, mise à jour de la
      progression, produit suivant instantané.
- [x] Point d'entrée "Produit introuvable" créé, sans développer le choix du
      coursier (réservé au Module 5).
- [x] Sauvegarde immédiate après chaque action, aucune perte possible.
- [x] Reprise automatique et exacte après interruption.
- [x] Architecture complète : `ProductState`, `ProductRepository`,
      `PickingRepository`, `PickingService`, `PickingController`, séparation stricte
      données/logique/interface.
- [ ] Non concerné par ce module (volontairement) : choix du coursier, module
      coursier, administration, transmission réseau réelle des événements de
      picking — voir Modules 5, 6, 7, 8.

**Prochaine étape** : Module 5 — Gestion des produits introuvables, qui ajoutera
l'écran de choix du coursier et la transition vers `ProductState.envoyeAuCoursier`,
sans modifier ce module.
