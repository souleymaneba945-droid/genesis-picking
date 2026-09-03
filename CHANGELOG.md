# CHANGELOG — GENESIS PICKING

Tenu à partir du Module 4, comme demandé. Les modules 1 à 3 ne sont pas
rétroactivement détaillés ici ; leur historique reste dans `MODULE_2.md` et
`MODULE_3.md` (le Module 1 est décrit dans `README.md`).

---

## Développement de production — écrans définitifs

Aucune nouvelle donnée fictive, aucune démonstration. Constat de départ : la
plupart des écrans demandés existaient déjà (Connexion, Tableau de bord, Mes
tournées, Écran de picking, Choix du coursier, Interface coursier,
Synchronisation) — ce livrable les a passés en revue et a construit les trois
manquants (Détail d'une tournée, Paramètres, Profil utilisateur).

### Ajouté
- `ProductNotFoundScreen` : écran "Produit introuvable" dédié (Cahier des charges,
  écran 3.11), qui qualifie une quantité partiellement trouvée avant d'escalader
  uniquement la quantité manquante au coursier — auparavant, "Introuvable" menait
  directement au choix du coursier pour la quantité totale, sans distinction
  partiel/total. Réutilise `PickingController.validerProduitCourant`/
  `signalerIntrouvable` (Module 4, inchangés) : ce nouvel écran ne décide jamais
  lui-même de l'état du produit, seulement de la quantité à transmettre.
- `TourDetailScreen` : écran "Détail d'une tournée" pour le préparateur (numéro,
  état, progression, action principale en très grand bouton) — accessible en
  touchant une carte dans "Mes tournées".
- `SettingsScreen` (Paramètres) : version et environnement réels de l'application,
  raccourcis vers Synchronisation et Profil.
- `ProfileScreen` (Profil utilisateur) : identité et rôle du compte connecté,
  changement de mot de passe (réutilise `ResetPasswordDialog`, Module 2, sans
  dupliquer sa logique), déconnexion.
- `TourStatusBadge`/`TourStatusChip` et `TourActionButton` : composants
  réutilisables extraits de "Mes tournées", partagés avec "Détail d'une tournée".
- `AppNavigationGuard` : logique de redirection du routeur extraite en fonctions
  pures et testables, sans changement de comportement.
- Tests de navigation (`app_navigation_guard_test.dart`) et de composant
  (`tour_action_button_test.dart`).

### Modifié
- `PickingScreen` : le bouton "Introuvable" ouvre désormais `ProductNotFoundScreen`
  au lieu de signaler directement l'état et de sauter vers le choix du coursier.
- `AppDimensions.primaryButtonHeight` : 56 → 64 (Directive : "très grands
  boutons") — répercuté automatiquement partout via `PrimaryButton`/`SecondaryButton`
  /`AppTheme`, sans toucher aux écrans un par un.
- `AppTypography.fontFamily` : la police "Inter", jamais réellement embarquée
  depuis le Module 1 (aucun asset de police dans le projet), est remplacée par
  `null` explicite (police système : Roboto sur Android) — corrige un écart
  silencieux entre le code et son intention, sans changement visuel côté Android.
- `app_router.dart` : délègue désormais sa logique de redirection à
  `AppNavigationGuard` — comportement strictement identique, testable
  indépendamment de `GoRouter`.
- `MyToursScreen`, `CourierHomeScreen`, `AdminDashboardScreen` : accès à
  "Paramètres" ajouté dans l'AppBar ; icône Synchronisation directe consolidée
  dans Paramètres côté Administrateur (déjà 4 autres icônes sur cet écran) pour
  éviter la surcharge visuelle, conservée en accès direct côté Préparateur/Coursier
  (consultation plus fréquente sur le terrain).

### Limitations connues
- `AppConstants.appVersion` est une constante à synchroniser manuellement avec
  `pubspec.yaml` (aucune dépendance supplémentaire ajoutée uniquement pour la lire
  à l'exécution).
- Comme pour tous les livrables précédents, `flutter analyze`/`flutter test`/
  `flutter run` n'ont pas pu être exécutés dans cet environnement (SDK Flutter/Dart
  absent).

---

## Moteur d'import des picking lists

Voir `MODULE_IMPORT.md` pour le rapport complet.

### Ajouté
- `ImportEngine`, architecture indépendante du format (`ImportParser`), registre
  de 4 analyseurs réels : `PDFParser` (calibrage requis), `CSVParser`,
  `ExcelParser`, `JSONParser`.
- `ImportValidator` : vérifie tournée/produits/images/emplacements/quantités sans
  jamais lever d'exception.
- `ImportReport`, `ImportHistoryTable`/`ImportRepository` : rapport et historique
  complet (date, utilisateur, durée, format, résultat, erreurs).
- Identifiant de tournée déterministe (dérivé du numéro) : base à la fois de la
  reprise après interruption et de la protection contre les doublons, sans
  mécanisme dédié supplémentaire.
- `AdminImportScreen` : sélection d'un vrai fichier, choix du préparateur,
  affichage du rapport.
- Tests : petit fichier, gros fichier (400-500 produits), fichier incomplet,
  doublons, erreur de structure (3 niveaux), import interrompu/repris.

### Modifié
- `TourRemoteSource` (Module 3) : `DemoTourRemoteSource` remplacée par
  `NoTourRemoteSource` — **l'application ne génère plus aucune donnée de
  démonstration**. `TourRepository`/`TourService` inchangés.
- `AdminDashboardScreen` : ajout d'un accès à l'écran d'import.
- Base de données locale : schéma v6 → v7 (`ImportHistoryTable`), sans perte de
  données.

### Dépendances ajoutées
`csv`, `excel`, `syncfusion_flutter_pdf` (licence communautaire, seuils à
vérifier), `file_picker`.

### Limitations connues
- Le format exact des exports CSV/Excel/JSON du logiciel de gestion n'est pas
  confirmé : ces trois analyseurs sont réels mais non calibrés sur un vrai
  fichier, contrairement au PDF.
- Le motif de reconnaissance des lignes produit du `PDFParser` est une hypothèse
  raisonnable, à calibrer dès qu'un exemplaire réel de picking list myFulfillment
  sera disponible.
- L'intégration API (option 5) reste bloquée côté BoostMyShop (erreur de session
  PHP, réglages API absents du compte) — hors de portée de ce livrable logiciel.
- `flutter pub get`/`analyze`/`test`/`run` n'ont pas pu être exécutés dans cet
  environnement (SDK Flutter/Dart absent, `pub.dev` inaccessible).

---

## Module 9 — Stabilisation, Optimisation et Qualité

Aucune fonctionnalité nouvelle, aucun nouvel écran, aucun changement de
comportement métier — voir `MODULE_9.md` pour le rapport complet (audit,
performance, sécurité, tests, robustesse, qualité).

### Corrigé
- **Sécurité** : faille de contrôle d'accès par rôle au niveau du routeur — un
  utilisateur authentifié pouvait en théorie atteindre l'accueil d'un autre rôle ;
  le routeur impose désormais la correspondance rôle/route.
- **Robustesse** : 8 écrans (`AdminDashboardScreen`, `AdminHistoryScreen`,
  `AdminCourierRequestsScreen`, `UserManagementScreen`, `CourierSelectionScreen`,
  `MyCourierRequestsScreen`, `CourierRequestDetailScreen`, `MyToursScreen`) ne
  géraient pas la branche d'erreur de leur `FutureBuilder` (risque de chargement
  infini) — corrigé partout avec un message explicite.
- **Robustesse** : 3 forçages de non-nullité (`ref.read(sessionProvider)!`)
  remplacés par des gardes défensives, sans changement de comportement dans le cas
  normal.

### Optimisé
- `DriftProductRepository.listForTour()` et `ensureStatusesInitialized()` :
  élimination d'un schéma N+1 requêtes (une requête par produit) au profit d'une
  requête groupée et d'une insertion en lot — comportement identique, nombre de
  requêtes divisé par la taille de la tournée.

### Nettoyé
- Suppression de `TourProductLine` (Module 3), jamais utilisée depuis que le
  Module 4 a construit `PickingProduct`.
- Suppression de `SyncQueue.markAsSynced()`/`markAsFailed()` (Module 1), plus
  aucun appelant depuis le Module 6.
- Retrait de la dépendance `cupertino_icons`, jamais utilisée.
- `picking_screen.dart` (358 lignes, 5 classes) éclaté en `picking_screen.dart` +
  3 fichiers sous `widgets/` (`progress_bar.dart`, `product_card.dart`,
  `tour_complete_view.dart`).

### Dette technique restante (documentée, non corrigée dans ce module)
- Système d'internationalisation (`AppLocalizations`) posé au Module 1 mais jamais
  branché à un écran — tous les textes sont en français en dur.
- Mot de passe administrateur par défaut codé en dur dans le binaire
  (`DatabaseSeeder`) ; aucun mécanisme technique n'impose encore son changement.
- Aucun test de widget, d'intégration ou de navigation n'existe (seuls des tests
  unitaires sur les couches `domain`/`data`, ≈87 cas au total).
- `SyncTransport` reste une simulation : aucun serveur réel n'existe.
- `DriftCourierRepository.countOpenRequestsFor()` pourrait être optimisée en
  `COUNT` SQL si le volume de demandes augmentait fortement.

### Limitations connues
- Comme pour tous les modules précédents, `flutter analyze`/`flutter test`/
  `flutter run` n'ont pas pu être exécutés dans cet environnement de conception
  (absence du SDK Flutter/Dart) : les corrections ont été vérifiées par relecture,
  pas par exécution.

---

## Module 8 — Administration

### Ajouté
- `AdministrationService` : tournées actives, historique, vue globale des
  demandes coursier, liste des préparateurs actifs, réassignation de tournée.
- Écrans `AdminDashboardScreen`, `AdminCourierRequestsScreen`,
  `AdminHistoryScreen`.
- Tests unitaires : séparation actives/historique, filtrage des préparateurs
  actifs, réassignation (succès, tournée terminée, tournée introuvable), vue
  globale des demandes.

### Modifié
- `TourRepository` : ajout additif de `listAll()` et `reassignPreparateur()`.
- `CourierRepository` : ajout additif de `listAll()`.
- `DriftTourRepository`/`DriftCourierRepository` : implémentations correspondantes.
- `FakeTourRepository`/`FakeCourierRepository` (tests, Modules 3 et 5) : mis à jour
  pour rester conformes aux interfaces étendues.
- Routeur : l'accueil Administrateur pointe désormais vers `AdminDashboardScreen`.
- Gestion des comptes (Module 2) et Synchronisation (Module 6) désormais
  accessibles depuis le tableau de bord Administrateur.

### Corrigé
- Sans objet — premier livrable de ce sous-module.

### Supprimé
- `features/home_placeholder/` (écran provisoire du Module 1) : plus aucun point
  d'entrée dans le routeur depuis que les trois rôles ont leur véritable écran.

### Limitations connues
- Aucune connexion à Drift/SQLite n'a pu être exécutée réellement dans cet
  environnement de conception (absence du SDK Flutter/Dart).
- Aucune pagination sur les listes globales (tournées, demandes) — non nécessaire
  au volume actuel, à surveiller si l'usage s'étend à de nombreuses pharmacies.
- La réassignation ne notifie pas activement l'ancien ni le nouveau préparateur
  (pas de notification push) — celui-ci verra la tournée apparaître/disparaître de
  "Mes tournées" à sa prochaine consultation de l'écran, cohérent avec le modèle
  offline-first déjà en place partout ailleurs dans le projet.

---

## Module 6 — Synchronisation

### Ajouté
- `SyncPriority` (basse/normale/haute) et l'état `SyncEventStatus.retrying` ("À
  réessayer"), distinct de l'échec définitif.
- Colonnes `priority`, `lastAttemptAt`, `lastError` sur `SyncEventsTable`.
- `SyncRunLogsTable` : journal des exécutions de synchronisation.
- `NetworkMonitor` (+ interface `ConnectivityState`) : détection réseau à
  responsabilité unique, seule classe du projet à parler à `connectivity_plus`.
- `SyncRepository` / `DriftSyncRepository` : accès aux données pour le moteur de
  synchronisation (distinct de `SyncQueue`, qui reste le point de dépôt pour les
  modules métier).
- `SyncTransport` / `SimulatedSyncTransport` : abstraction de transmission vers un
  serveur, avec implémentation de démonstration en attendant un vrai backend.
- `ConflictResolver` : stratégies de résolution testées pour les trois cas de la
  Directive (mise à jour concurrente, suppression de tournée modifiée, réponse
  coursier concurrente) plus un cas générique "dernière écriture gagne".
- `SyncService` : boucle de traitement priorisée, déclenchement automatique au
  retour du réseau, gestion des tentatives (À réessayer → Échec), protection
  contre les exécutions concurrentes, journalisation complète.
- `SyncController` + `SyncScreen` : écran Synchronisation (dernière synchronisation,
  éléments en attente, état actuel, bouton "Synchroniser maintenant").
- Points d'accès à l'écran Synchronisation depuis les accueils Préparateur,
  Coursier et Administrateur.
- Tests unitaires complets : synchronisation sans erreur, coupure réseau en cours
  de synchronisation, reprise, doublons, conflits, 300 opérations en attente,
  synchronisation après plusieurs jours hors connexion.

### Modifié
- `SyncQueue`/`SyncEventSink` (Module 1) : `enqueue()` accepte désormais un
  paramètre `priority` optionnel (défaut `normale`) — tous les appels existants
  des Modules 3, 4 et 5 restent valides sans modification.
- `SyncManager` (Module 1) : la détection réseau est déléguée à `NetworkMonitor` en
  interne ; API publique strictement inchangée (`courier_availability_checker.dart`,
  Module 5, n'a nécessité aucune modification).
- `core_providers.dart` : ajout de `networkMonitorProvider`, partagé entre
  `SyncManager` et `SyncService`.
- Base de données locale : schéma v5 → v6, migration sans perte de données.

### Corrigé
- Sans objet — premier livrable de ce sous-module.

### Limitations connues
- Aucune connexion à Drift/SQLite n'a pu être exécutée réellement dans cet
  environnement de conception (absence du SDK Flutter/Dart).
- `SimulatedSyncTransport` ne représente aucun serveur réel : la transmission
  effective vers un backend reste à implémenter (nouvelle implémentation de
  `SyncTransport` uniquement, sans toucher au reste du moteur).
- `ConflictResolver` est entièrement testé de façon isolée mais n'est pas encore
  appelé en conditions réelles, faute de source de conflit distante existante
  (aucun backend réel) — il est prêt à être branché dès que `SyncTransport` aura
  une vraie implémentation.
- Le seuil de nouvelle tentative (5 par défaut) est une valeur raisonnable non
  spécifiée précisément par la Directive ; configurable via le constructeur de
  `SyncService`.

---

## Module 5 — Gestion des produits introuvables & Coursiers

### Ajouté
- `CourierRequestStatus` (6 états) et `CourierRequestResult` (2 issues).
- `CourierRequestsTable` : table Drift des demandes coursier, avec instantané des
  quantité/emplacement au moment de la création.
- `CourierRequest`, `CourierSummary`, `CourierRequestDetailView` : modèles de
  domaine.
- `CourierRepository` / `DriftCourierRepository` : accès aux données.
- `CourierAvailabilityChecker` / `SyncManagerAvailabilityChecker` : détection de
  disponibilité réseau, réutilisant le `SyncManager` du Module 1.
- `CourierService` : liste des coursiers actifs avec charge ouverte, création de
  demande, réception avec synchronisation ultérieure, ouverture/acceptation,
  réponse (retrouvé/non retrouvé), retour préparateur automatique.
- `CourierController` (Riverpod `AsyncNotifier`) : état de la liste des demandes du
  coursier connecté.
- Écrans : `CourierSelectionScreen` (choix du coursier, préparateur),
  `CourierHomeScreen` (accueil coursier, liste minimale), 
  `CourierRequestDetailScreen` (traitement, coursier), `MyCourierRequestsScreen`
  (retour préparateur).
- Tests unitaires complets : création, choix du coursier, réception, validation,
  retour préparateur, reprise après fermeture, fonctionnement hors connexion.

### Modifié
- `PickingController` (Module 4) : ajout strictement additif de
  `marquerEnvoyeAuCoursier(productLineId)`, qui réutilise la méthode générique déjà
  existante `PickingService.validateCurrentProduct` — **aucune ligne de
  `PickingService` n'a été modifiée**.
- `PickingScreen` : le bouton "Introuvable" ouvre désormais `CourierSelectionScreen`
  après avoir signalé le produit introuvable, au lieu de rester sur place.
- `MyToursScreen` : ajout d'un accès à "Mes demandes coursier" dans l'AppBar.
- Routeur (`app_router.dart`) : l'accueil Coursier pointe désormais vers
  `CourierHomeScreen` au lieu de l'écran provisoire du Module 1.
- Base de données locale : schéma v4 → v5 (ajout de `CourierRequestsTable`),
  migration sans perte de données.

### Corrigé
- Sans objet — premier livrable de ce sous-module.

### Limitations connues
- Aucune connexion à Drift/SQLite n'a pu être exécutée réellement dans cet
  environnement de conception (absence du SDK Flutter/Dart).
- La transition "Traitée → Terminée" se fait dès consultation par le préparateur,
  simplification assumée tant qu'aucune synchronisation multi-appareils réelle
  (Module 7) n'existe ; un déploiement réel attendrait la confirmation de
  synchronisation avant cette clôture.
- "Priorité" du coursier est calculée (rang par ancienneté), pas stockée — aucune
  notion d'urgence distincte de l'ordre d'arrivée n'a été demandée par la Directive.
- Si le préparateur annule l'écran de choix du coursier sans sélectionner personne,
  le produit reste à l'état "Introuvable" sans demande associée — comportement
  assumé, aucun mécanisme de correction n'a été développé (pas de retour manuel
  autorisé par le Module 4).
- Couplage bidirectionnel entre les modules Picking et Coursier (l'écran de picking
  ouvre l'écran de choix du coursier ; le module coursier lit le dépôt de produits
  du Module 4 pour l'affichage) — inhérent à la fonctionnalité demandée, documenté
  plutôt que masqué.
- Événements de synchronisation coursier déposés dans la file générique du
  Module 1, sans transmission réelle — réservée au Module 7.


## Module 4 — Moteur de Picking

### Ajouté
- `ProductState` : les cinq états de collecte d'un produit (À récupérer, Collecté,
  Partiellement collecté, Introuvable, Envoyé au coursier).
- `PickingProductStatusesTable` : table Drift compagne de `TourProductLinesTable`,
  en relation un-à-un, portant l'état de collecte de chaque produit.
- `ProductRepository` / `DriftProductRepository` : CRUD pur sur les produits et
  leur état.
- `PickingRepository` / `DriftPickingRepository` : orchestration atomique
  (état produit + progression de la tournée dans une seule transaction).
- `PickingService` : chargement d'une session de picking, validation d'un produit,
  point d'entrée "Produit introuvable", reprise automatique.
- `PickingController` (Riverpod `FamilyAsyncNotifier`, un par tournée) : état
  d'écran, délègue entièrement la logique à `PickingService`.
- `PickingScreen` : écran de collecte guidée, un seul produit à la fois, ordre
  emplacement → quantité → image → nom → description ; barre de progression
  (traités/total/pourcentage) ; boutons "Produit trouvé" / "Introuvable".
- Vue de fin de tournée (intégrée à `PickingScreen`) proposant la clôture via
  `TourService.completeTour` (Module 3), une fois tous les produits traités.
- Tests unitaires : `picking_service_test.dart`, `fake_picking_repository.dart`.

### Modifié
- `TourRepository` (Module 3) : ajout de `updateProgress()` — strictement
  additif, aucune méthode existante retirée ni changée.
- `DriftTourRepository` : implémentation de `updateProgress()`.
- `FakeTourRepository` (test, Module 3) : mise à jour pour rester conforme à
  l'interface `TourRepository` étendue.
- `MyToursScreen` (Module 3) : "Commencer"/"Reprendre" ouvre désormais
  `PickingScreen` au lieu de l'écran de détail provisoire.
- Base de données locale : schéma v3 → v4 (ajout de
  `PickingProductStatusesTable`), migration sans perte de données.

### Corrigé
- Sans objet — premier livrable de ce sous-module, aucune régression à corriger
  par rapport à une version antérieure du moteur de picking (qui n'existait pas).

### Limitations connues
- Aucune connexion à Drift/SQLite n'a pu être exécutée réellement dans cet
  environnement de conception (absence du SDK Flutter/Dart) : le code a été écrit
  et relu avec rigueur, mais `flutter test`/`flutter run` restent à exécuter dans
  un environnement de développement réel avant mise en usage.
- `ProductState.envoyeAuCoursier` est défini mais inatteignable : sa transition
  réelle arrive avec le Module 5.
- Aucune méthode de retour au produit précédent — décision volontaire (Directive :
  "aucun retour manuel nécessaire"), pas une omission.
- Aucun événement de picking n'est déposé dans la file de synchronisation générique
  du Module 1 : la Directive exclut la synchronisation complète de ce module, et la
  bonne granularité d'événements (par produit ? par tournée clôturée ?) est laissée
  au Module 7.
- Pas de limite de taille testée sur le nombre de produits d'une tournée ; à
  surveiller si ce nombre devient très élevé (peu probable au vu du contexte de
  livraison en pharmacie).
