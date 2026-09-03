# GENESIS PICKING — Module 8 : Administration

Tableau de bord complet de l'Administrateur, au-delà de la gestion des comptes déjà
livrée au Module 2. Aucune nouvelle table : ce module n'est qu'une couche
d'orchestration en lecture (et une seule action d'écriture : la réassignation) au-dessus
des dépôts déjà construits par les Modules 2, 3 et 5.

---

## 1. Architecture

```
lib/features/administration/
├── administration_providers.dart
├── domain/
│   └── administration_service.dart   # AdministrationService — agrégation pure
└── presentation/
    ├── admin_dashboard_screen.dart          # Tableau de bord (écran 4.13)
    ├── admin_courier_requests_screen.dart   # Vue globale des demandes (3.5)
    └── admin_history_screen.dart            # Historique (3.6)

lib/features/tours/data/tour_repository.dart       [MODIFIÉ] + listAll(),
                                                        + reassignPreparateur()
lib/features/tours/data/drift_tour_repository.dart  [MODIFIÉ] implémentations
lib/features/courier/data/courier_repository.dart   [MODIFIÉ] + listAll()
lib/features/courier/data/drift_courier_repository.dart  [MODIFIÉ] implémentation

lib/core/navigation/app_router.dart   [MODIFIÉ] accueil Administrateur →
                                         AdminDashboardScreen
lib/features/home_placeholder/        [SUPPRIMÉ] entièrement — les trois rôles ont
                                         désormais chacun leur véritable écran

test/features/administration/administration_service_test.dart
test/features/tours/fake_tour_repository.dart      [MODIFIÉ] conformité d'interface
test/features/courier/fake_courier_repository.dart [MODIFIÉ] conformité d'interface
```

### `AdministrationService` : agrégation, jamais de logique dupliquée
Ce service ne fait QUE lire (`listAll()` sur les tournées et les demandes coursier,
`listAll()` filtré sur les comptes) et, pour l'unique action d'écriture
(réassignation), déléguer directement à `TourRepository.reassignPreparateur()`.
Aucune règle de picking, de collecte ou de traitement coursier n'est reproduite —
c'est le test le plus simple de la bonne séparation des responsabilités déjà posée
dans les modules précédents : si `AdministrationService` avait dû "deviner" un état
métier, cela aurait signalé une fuite de logique depuis un autre module.

### Extensions additives à `TourRepository` et `CourierRepository`
Les Modules 3 et 5 n'exposaient que des vues filtrées par utilisateur
(`listForPreparateur`, `listForCoursier`, `listForPreparateur` côté coursier).
L'Administration a besoin d'une vue globale : `listAll()` a été ajoutée aux deux
interfaces, ainsi que `reassignPreparateur()` sur `TourRepository`. Ces ajouts sont
strictement additifs : aucune méthode existante n'a été modifiée, et les Modules 3,
4 et 5 ne les appellent jamais.

### Réassignation : un seul garde-fou, explicite
`reassignerTournee()` refuse la réassignation d'une tournée déjà "Terminée" — un
historique ne doit jamais être modifié après coup. Testé explicitement.

### Écrans séparés plutôt qu'un tableau de bord unique surchargé
Conformément au principe "un écran, une décision" (Document UX/UI), le tableau de
bord ne montre que les tournées actives + l'action de réassignation ; les demandes
coursier (vue globale) et l'historique sont des écrans séparés, accessibles depuis
l'AppBar. La gestion des comptes (Module 2) et la synchronisation (Module 6) sont
également accessibles depuis là — ce sont les seuls points d'entrée qui existaient
jusqu'ici dans l'écran provisoire du Module 1, désormais entièrement supprimé.

### Suppression de `features/home_placeholder/`
Les trois rôles ont maintenant chacun leur véritable écran d'accueil
(`AdminDashboardScreen`, `MyToursScreen`, `CourierHomeScreen`). L'écran provisoire
posé au Module 1 n'avait plus aucun point d'entrée dans le routeur : il a été
supprimé plutôt que laissé comme code mort.

---

## 2. Migrations de la base locale

Aucune. Ce module n'introduit ni ne modifie aucune table — il ne fait
qu'orchestrer des lectures et une écriture déjà couvertes par le schéma existant
(v6, posé au Module 6).

---

## 3. Tests réalisés

`administration_service_test.dart` :
- Séparation correcte des tournées actives et de l'historique.
- Filtrage des préparateurs actifs uniquement (un préparateur désactivé disparaît).
- Réassignation réussie d'une tournée active, avec vérification que le dépôt est
  bien mis à jour.
- Refus de réassigner une tournée déjà terminée, avec vérification que rien n'a
  changé.
- Refus de réassigner une tournée introuvable.
- Vue globale des demandes coursier : toutes remontent, quel que soit le
  préparateur ou le coursier d'origine.

### Même limite technique que les modules précédents
Cet environnement de conception ne dispose toujours pas du SDK Flutter/Dart :
`flutter test`/`flutter run` n'ont pas pu être exécutés concrètement ici.

```bash
flutter test
flutter run
```

---

## 4. Checklist de validation — Module 8

- [ ] Le tableau de bord affiche toutes les tournées non terminées, tous
      préparateurs confondus.
- [ ] La réassignation d'une tournée à un autre préparateur actif fonctionne et se
      reflète immédiatement dans la liste.
- [ ] Une tournée déjà terminée ne peut pas être réassignée.
- [ ] La vue globale des demandes coursier montre toutes les demandes, avec leur
      état.
- [ ] L'historique n'affiche que les tournées terminées.
- [ ] La gestion des comptes (Module 2) et la synchronisation (Module 6) restent
      accessibles depuis l'accueil Administrateur.

---

## 5. Points validés

- [x] Tableau de bord Administrateur fonctionnel (écran 4.13 du Cahier des charges).
- [x] Réassignation de tournée, avec garde-fou sur les tournées terminées.
- [x] Vue globale des demandes coursier (écran 3.5).
- [x] Historique des tournées terminées (écran 3.6).
- [x] Aucune logique dupliquée : ce module ne fait qu'agréger et orchestrer des
      dépôts déjà construits par les Modules 2, 3 et 5.
- [x] Écran provisoire du Module 1 entièrement retiré, les trois rôles ayant
      désormais chacun leur véritable interface.

**Prochaine étape** : Module 9 — Optimisation et performances, puis Module 10 —
Préparation de la version 1.0 (selon le plan initial).
