# Module 5 v2 — Améliorations Coursier (Cahier des charges additionnel)

Ce document consigne les nouvelles rubriques demandées pour améliorer le travail du
coursier, en complément de la Directive Module 5 d'origine (voir `MODULE_5.md`).
Aucune de ces rubriques n'est encore implémentée — ce fichier sert de spécification
à valider avant tout développement, conformément à la demande de l'utilisateur
(08/09/2026) : "rien publier ni compiler sans accord".

Chaque rubrique est numérotée et datée à sa définition ; son statut passe de
**Spécifiée** → **En cours** → **Implémentée** au fil du travail.

---

## Rubrique 1 — Liste fusionnée, sans doublon, indépendante du préparateur

**Statut : Implémentée (09/09/2026)** — code écrit et testé (`flutter analyze`
propre, 197/197 tests passent), PAS compilée ni publiée (voir consigne
utilisateur du 08/09/2026).

### Problème actuel

L'écran "Demandes" du coursier regroupe les demandes **par préparateur** (une ligne
par préparateur, avec un menu déroulant listant ses demandes). Si deux préparateurs
différents signalent le même produit introuvable (chacun sur sa propre tournée), le
coursier voit deux demandes séparées pour un seul et même produit à aller chercher.

### Comportement demandé

- Les demandes ne sont plus groupées par préparateur : le coursier voit **une seule
  liste plate** de tous les produits à retrouver.
- **Détection de doublon** : deux demandes portant sur le même produit sont
  reconnues comme UNE SEULE entrée dans cette liste. Le critère de reconnaissance
  est le **code référence exact** du produit (champ `produitDescription`, ex.
  `"234187 - 8800256119660"` — extrait tel quel du PDF importé, voir
  `PdfParser._combineRefs`), jamais une comparaison de nom (trop de variations
  d'écriture possibles entre deux tournées différentes).
- **Quantité** : la ligne fusionnée n'affiche PAS de quantité additionnée — elle
  indique simplement que le produit est demandé (le coursier gère la quantité à
  ramener sur place, pas un total calculé par l'app).
- **Résolution** : quand le coursier répond "Produit retrouvé" ou "Produit non
  retrouvé" sur une ligne fusionnée, cette réponse **clôture automatiquement la
  demande de chaque préparateur** ayant signalé ce produit — un seul geste du
  coursier, tous les préparateurs concernés reçoivent le résultat dans leur écran
  "Vérifications" (Module 5 d'origine, "Retour préparateur").

### Points d'implémentation identifiés (à affiner à l'implémentation)

- La donnée reste **par préparateur** en base (`CourierRequestsTable` inchangée —
  voir la contrainte "donnée PDF immuable, complétée seulement par tables
  additives") : la fusion est un regroupement d'AFFICHAGE et de RÉSOLUTION, pas une
  fusion de la donnée source. Chaque `CourierRequest` individuelle continue
  d'exister ; seule la présentation au coursier et l'action "répondre" changent.
- `CourierController`/`CourierService.listRequestsForCoursierWithPreparateur` :
  actuellement retourne une liste de résumés par demande individuelle — à adapter
  pour grouper par `produitDescription` avant affichage, tout en conservant assez
  d'information pour résoudre TOUTES les demandes du groupe en une action.
  Nécessite une méthode du type `CourierService.respondToGroup(reference, resultat)`
  qui itère sur toutes les `CourierRequest` ouvertes partageant cette référence.
- Écran concerné : `CourierRequestsTab`/`courier_request_detail_screen.dart`
  (`features/courier/presentation/`).
- `CourierNotificationWatcher` (notification système à l'arrivée d'une demande) :
  à vérifier que la détection de "nouvelle arrivée" continue de fonctionner
  correctement une fois la liste affichée fusionnée (elle raisonne aujourd'hui sur
  les `CourierRequest` individuelles, pas sur le groupe — a priori compatible sans
  changement, à confirmer à l'implémentation).
- Produit sans référence (cas rare, champ absent) : jamais fusionné avec un autre
  (pas de fusion "à l'aveugle" sur une référence vide) — reste affiché seul, comme
  aujourd'hui.

---

## Rubrique 2 — Cartographie entrepôt par marque (emplacement coursier)

**Statut : Implémentée (09/09/2026)** — code écrit et testé (`flutter analyze`
propre, 209/209 tests passent). `firestore.rules` modifié (nouveau bloc
`marque_emplacements`) mais **PAS déployé** — sans ce déploiement, la
synchronisation entre appareils de cette rubrique ne fonctionnera pas
(échec silencieux en `permission-denied`), mais tout fonctionne déjà en
local sur un seul appareil. Déploiement en attente d'un accord explicite
séparé (voir consigne utilisateur du 08/09/2026).

**Ajout (13/09/2026, maquette v0.dev `brand-locations-screen.tsx`)** :
import en masse marque/emplacement depuis un fichier `.csv`/`.xlsx`, en plus
de la saisie une par une déjà existante — voir
`lib/features/warehouse_location/domain/brand_location_import.dart`
(analyse pure du fichier, classification nouveau/mise à jour/erreur par
comparaison avec l'existant) et `warehouse_location_management_screen.dart`
(zone de dépôt + aperçu avant confirmation). Aucune règle métier changée :
toujours la même table, le même dépôt, la même contrainte
d'indépendance stricte avec l'emplacement PDF.

### Principe — deux notions d'emplacement STRICTEMENT séparées

Il existe déjà un champ "emplacement" (ex. `"A10"`) sur chaque ligne produit,
extrait tel quel du PDF de picking (`TourProductLinesTable.emplacement`,
`ParsedProduit.emplacement`) — c'est l'emplacement où le PRÉPARATEUR va chercher le
produit pour constituer une commande, fourni par le logiciel de gestion
(myFulfillment), jamais modifié par l'application (voir la contrainte "donnée PDF
importée immuable").

Cette rubrique ajoute une **seconde notion, totalement indépendante** :
l'emplacement où sont rangés les produits **dans l'entrepôt physique**, à
destination du COURSIER (pas du préparateur). Ces deux emplacements :
- n'ont **aucun rapport** l'un avec l'autre (un produit peut être en `"A10"` pour le
  picking et rangé en `"Zone C"` dans l'entrepôt — deux informations indépendantes),
- ne doivent **jamais être mélangés** dans le code, la base, ni l'affichage — deux
  champs, deux tables, deux libellés distincts à l'écran,
- ont une origine différente : le premier vient du PDF (myFulfillment), le second
  est saisi et maintenu **par l'administrateur lui-même** dans l'app, jamais
  extrait d'un PDF.

### Comportement demandé

- L'administrateur maintient une liste de correspondances **marque → emplacement
  entrepôt** (ex. `"Mustela" → "Zone A - Étagère 3"`, `"Topicrem" → "Zone B"`) —
  granularité par MARQUE uniquement, jamais produit par produit.
- Détection de la marque d'un produit : le nom du produit (`produitNom`) **commence
  par** le nom d'une marque connue (comparaison insensible à la casse) — pas une
  recherche n'importe où dans le nom, pour éviter les fausses correspondances. Si
  plusieurs marques connues correspondent (cas rare, ex. une marque nom préfixe
  d'une autre), la plus longue l'emporte (la plus spécifique).
- Emplacement entrepôt : champ texte libre, sans structure imposée (même principe
  que l'emplacement picking existant).
- Si la marque d'un produit n'est pas encore dans la liste de l'administrateur, le
  coursier voit un message explicite **"Emplacement entrepôt non renseigné"**
  (visible, pour que l'administrateur repère facilement les marques encore
  manquantes au fil de l'usage réel).

### Points d'implémentation identifiés (à affiner à l'implémentation)

- Nouvelle table locale (Drift), indépendante de `TourProductLinesTable` et de
  `CourierRequestsTable` — ex. `BrandWarehouseLocationsTable` (`marque`,
  `emplacementEntrepot`) — nouvelle migration de schéma (voir
  `local_database.dart`, `schemaVersion`).
- Donnée maintenue par l'administrateur, doit être visible par tous les coursiers
  sur tous les appareils : suit le même schéma que le reste (push/pull Firestore,
  voir "Real cross-device sync" dans `CLAUDE.md`) — **nécessite une nouvelle
  collection Firestore avec son propre bloc de règles dans `firestore.rules`,
  déployé (`firebase deploy --only firestore:rules`)**. Piège déjà rencontré deux
  fois sur ce projet (`courier_requests`, comptes admin dupliqués) : ne JAMAIS
  oublier cette étape, sous peine d'échecs silencieux en `permission-denied`.
- Nouvel écran Administration : gestion de la liste marque → emplacement (créer /
  modifier / supprimer), même famille que la gestion des comptes utilisateurs.
- Écran coursier concerné : `courier_request_detail_screen.dart` — nouveau champ
  "Emplacement entrepôt" affiché à côté (jamais fusionné avec) le champ
  "Emplacement" (picking) déjà présent.
- Logique de correspondance marque → produit : un service dédié (ex.
  `WarehouseLocationService.find(produitNom)`), jamais une comparaison inline dans
  un écran.

---

## Rubrique 3 — Révocation de compte et contrôle administrateur complet

**Statut : Implémentée (12/09/2026)** — code écrit et testé (`flutter analyze`
propre, 214/214 tests passent), rien compilé ni publié.

### Constat de départ

La fonctionnalité "Désactiver" (`UserRepository.setActive`) existe déjà, mais ne
fait que bloquer les FUTURES connexions (`AuthService.login`, vérification de
`account.actif`). Un compte déjà connecté sur un appareil garde l'accès
indéfiniment — `SessionManager.restoreSession()` ne revérifie jamais le statut du
compte, par conception (l'app doit rester utilisable hors-ligne indéfiniment une
fois connectée). Insuffisant pour une vraie révocation en cas de licenciement.

### Comportement demandé

- **Révocation à distance** : en plus de bloquer les futures connexions (déjà en
  place), une révocation doit fermer la session active sur l'appareil concerné dès
  que celui-ci retrouve le réseau — pas besoin d'action de l'utilisateur révoqué.
  Limite assumée et inévitable : sans réseau, aucune fermeture à distance n'est
  possible (l'appareil doit contacter le serveur pour apprendre la révocation) ;
  c'est la meilleure garantie possible pour une app volontairement hors-ligne.
- **Renommer l'identifiant** : l'administrateur peut changer l'identifiant de
  connexion (username) d'un compte existant — capacité absente aujourd'hui
  (`UserRepository` n'expose que `create`/`setActive`/`resetPassword`, jamais de
  renommage).
- **PAS de visualisation des mots de passe existants** — décision explicite,
  jamais à reconsidérer sans une vraie raison nouvelle : les mots de passe sont
  hachés (PBKDF2, irréversible par construction) et ne seront jamais stockés en
  clair. Stocker les mots de passe réels de l'équipe en clair dans une base dont
  les règles sont aujourd'hui ouvertes à tous (et dont le dépôt de code va
  devenir public) exposerait chaque compte à quiconque trouve la configuration du
  projet. Le contrôle total de l'administrateur passe par la réinitialisation
  (déjà en place) et le renommage (ci-dessus), jamais par la lecture.

### Points d'implémentation identifiés (à affiner à l'implémentation)

- Révocation à distance : nécessite un mécanisme de vérification périodique du
  statut `actif` du compte de la session EN COURS, quand le réseau est
  disponible — probablement accroché à `UserPullSync.pullAll()` (déjà exécuté au
  démarrage et pendant la synchronisation automatique) : si le compte de la
  session active revient avec `actif = false`, fermer la session
  (`SessionManager.closeSession()`) et rediriger vers l'écran de connexion, avec un
  message explicite ("Ce compte a été désactivé par un administrateur").
- Renommer l'identifiant : nouvelle méthode sur `UserRepository`
  (`renameIdentifiant` ou similaire), avec vérification d'unicité locale ET
  distante (éviter de recréer le même genre de doublon que le bug des comptes
  admin — voir `MODULE_5_V2.md` historique de cette semaine dans `CLAUDE.md`).
  Écran concerné : `user_management_screen.dart`.

---

## Rubrique 4 — Vérification du stock en direct (intégration BoostMyShop)

**Statut : Spécifiée (08/09/2026) — bloquée sur l'obtention d'un accès API**

Contrairement aux rubriques précédentes, celle-ci ne concerne pas QUE le
coursier : elle sert aussi le préparateur/administrateur. Conservée dans ce
document faute d'un meilleur endroit pour l'instant.

### Découverte importante

**BoostMyShop est l'éditeur de myFulfillment** — le logiciel qui produit déjà les
PDF de picking importés dans l'app (voir `pdf_parser.dart`, en-tête de classe :
"calibré sur la Feuille de préparation globale réellement exportée par
myFulfillment"). Ce n'est donc pas une intégration avec un système tiers
inconnu : c'est très probablement le même compte déjà utilisé pour l'export PDF.
BoostMyShop expose de vraies API REST pour le stock (niveaux par produit, par
entrepôt, mouvements) — une source bien plus fiable que l'extraction PDF actuelle,
qui reste fragile par nature (voir le recadrage des photos, Rubrique liée dans
`CHANGELOG.md`/historique du projet).

### Comportement demandé

- **Coursier** : sur une demande "produit introuvable", permettre de vérifier si
  le produit est encore disponible en stock ailleurs dans l'entrepôt avant de se
  déplacer pour rien.
- **Préparateur/admin** : un bouton "Vérifier le stock" — vérification À LA
  DEMANDE (pas automatique à l'import de la tournée), produit par produit ou pour
  toute la tournée d'un coup, pour repérer les produits épuisés.
- Fonctionnalité intrinsèquement dépendante du réseau (le stock "en direct" n'a
  pas de sens hors-ligne) — dégradation explicite et jamais bloquante si hors
  ligne (ex. "Stock non vérifié — hors connexion"), jamais une erreur qui casse
  l'écran, conformément au principe déjà en place partout ailleurs dans l'app
  (best-effort, voir `UserPullSync`/`FirestoreCourierRequestRemoteSource`).

### Bloquant avant toute implémentation

- **Accès API BoostMyShop** : nécessite de vérifier que l'abonnement myFulfillment
  actuel inclut l'accès API (parfois réservé à un palier supérieur), et d'obtenir
  les identifiants + la documentation technique précise (authentification,
  endpoints exacts, limites de débit) — rien de tout cela n'est public, il faut
  passer par le support BoostMyShop ou l'espace client. **Rien n'est
  implémentable tant que cet accès n'est pas obtenu.**
- Clé de correspondance produit ↔ BoostMyShop supposée : le code référence déjà
  utilisé (`produitDescription`, ex. `"234187 - 8800256119660"`), puisque c'est
  précisément myFulfillment qui produit ce code sur le PDF — à confirmer une fois
  l'accès API obtenu (peut différer du format attendu par leurs endpoints).

### Points d'implémentation identifiés (une fois l'accès obtenu)

- Nouveau module `lib/features/stock/` (même famille que `import/`) :
  `StockRemoteSource` (interface) + `BoostMyShopStockRemoteSource` (implémentation
  réelle) + `NoStockRemoteSource` (repli hors-ligne/sans accès), même schéma que
  les autres intégrations distantes du projet.
- Écran coursier : bouton "Vérifier le stock" sur `courier_request_detail_screen.dart`.
- Écran préparateur/admin : bouton "Vérifier le stock" sur l'écran de tournée
  (`picking_screen.dart` ou équivalent), par produit et/ou pour toute la tournée.

---

## Rubrique 4bis — Statistiques par marque des demandes coursier

**Statut : Implémentée (16/09/2026)** — code écrit et testé (`flutter analyze`
propre, 229/229 tests passent). Aucun déploiement requis (aucune nouvelle
collection Firestore, purement un calcul sur des données déjà synchronisées).

### Besoin exprimé

Objectif : identifier quelles marques reviennent le plus souvent dans les
demandes coursier ("produit introuvable"), pour décider soit d'augmenter leur
volume de stockage (si réellement épuisées), soit de repriorité leur
emplacement dans l'entrepôt (si le coursier les retrouve systématiquement —
signe qu'elles sont mal placées plutôt que manquantes).

### Comportement implémenté

- Nouvel écran Administrateur "Statistiques par marque", accessible depuis
  "Suivi" (icône graphique, à côté de "Historique") — pas un 6ᵉ onglet.
- Regroupement des demandes coursier par marque, avec EXACTEMENT la même règle
  de correspondance que l'emplacement entrepôt (Rubrique 2) : le nom du produit
  commence par une marque connue, la plus longue l'emporte — jamais une règle
  différente entre l'affichage courant et les statistiques
  (`WarehouseLocationService.matchMarque`, extrait en méthode statique
  réutilisable pour éviter un rechargement de la liste des marques à chaque
  demande).
- Une demande dont le produit ne correspond à aucune marque enregistrée (ou
  sans nom de produit du tout, donnée ancienne) tombe dans un panier "Marque
  non identifiée" — jamais fusionné à l'aveugle avec une vraie marque ; sert
  aussi de signal "cette marque mériterait d'être enregistrée".
- Par marque : total de demandes, ventilé en trouvés / non trouvés / encore en
  cours, triées de la plus fréquente à la moins fréquente, avec une barre de
  progression relative au maximum pour repérer les marques prioritaires d'un
  coup d'œil.
- Nouvelle méthode pure et testée séparément :
  `computeBrandRequestStats` (`lib/features/administration/domain/brand_request_stats.dart`)
  — `AdministrationService.statistiquesParMarque()` se contente de charger les
  deux listes puis d'appeler cette fonction, aucune règle métier dupliquée.

**Ajout (16/09/2026, retour explicite de l'utilisateur)** : vue Jour / Semaine /
Mois avec navigation période précédente/suivante ("Semaine du 14/09 au
20/09/2026", "Septembre 2026"...) — un seul chargement des données
(`AdministrationService.chargerDonneesStatistiquesMarque`), tout le filtrage
par période se fait ensuite en mémoire (`periodBounds`/`shiftPeriod`/
`filterByPeriod`/`periodLabel`, `lib/features/administration/domain/stats_period.dart`,
fonctions pures testées séparément). La semaine commence le lundi. "Suivant"
se désactive automatiquement une fois sur la période en cours (naviguer plus
loin ne montrerait que du vide).

---

## Rubrique 4ter — Statistiques de demande logistique (par produit)

**Statut : Implémentée (16/09/2026)** — cahier des charges détaillé fourni
directement par l'utilisateur, code écrit et testé. Remplace/élargit la
Rubrique 4bis (statistiques par marque seule), au même point d'accès depuis
"Suivi".

### Règle absolue (rappel)

Ce module ne connaît et ne prétend JAMAIS connaître le stock physique, la
quantité restante, vendue ou réapprovisionnée — uniquement la fréquence des
demandes coursier ("produit introuvable") déjà enregistrées. Vocabulaire
imposé : "forte demande détectée", "priorité picking", jamais "rupture de
stock" ni "augmenter le stock".

### Ce qui a été implémenté

- Regroupement par PRODUIT (référence exacte `produitDescription`, repli sur
  le nom si aucune référence — contrairement à la Rubrique 1, qui ne fusionne
  jamais deux demandes sans référence, ici un simple comptage rétrospectif).
- Classification RELATIVE au produit le plus demandé de la période (seuils
  75/50/25 % du max, constantes nommées et modifiables dans
  `demand_stats.dart`) : 🔴 très forte / 🟠 forte / 🟡 modérée / 🟢 faible
  demande.
- Priorité picking dérivée 1:1 de cette classification (🔴 priorité picking /
  🟠 à rapprocher / 🟡 à surveiller / 🟢 organisation standard) — jamais une
  déduction de rupture.
- Tendance : comparaison avec la période équivalente précédente (seuils
  ±15 %, constantes nommées) ; "données insuffisantes" si aucune donnée sur
  la période précédente.
- Écran "Statistiques de demande" (`admin_demand_stats_screen.dart`) :
  indicateurs (6 cartes), sélecteur Jour/Semaine/Mois/Période personnalisée
  (réutilise `stats_period.dart`), filtres (marque, emplacement, statut,
  recherche texte, réinitialisation), graphique "top produits" (barres
  simples, sans dépendance externe), tableau détaillé (rang/produit/SKU/
  marque/recherches/part/tendance/statut), observations logistiques générées
  automatiquement, section "Demande par marque" avec détail au clic
  (`BrandDemandDetailScreen`), section "Analyse des emplacements" (signal
  "Emplacement à vérifier" si ≥ 30 % de non-trouvés sur ≥ 3 recherches — un
  simple signal à vérifier, jamais un jugement définitif), export CSV
  (`file_picker`, BOM UTF-8 pour Excel FR).
- Domaine séparé en fonctions pures testées (`lib/features/administration/domain/demand_stats.dart`,
  `test/features/administration/demand_stats_test.dart`) — aucune règle
  dupliquée par rapport à l'existant (réutilise
  `WarehouseLocationService.matchMarque` pour la marque).

### Non repris de la Rubrique 4bis

L'ancien écran "Statistiques par marque" (`admin_brand_stats_screen.dart`),
ajouté puis aussitôt élargi dans la même session sans avoir été un point de
passage établi, a été retiré au profit de ce module unique — `brand_request_stats.dart`
reste en place (sa constante `marqueNonIdentifiee` est réutilisée ici).

---

## Rubriques suivantes

À définir avec l'utilisateur — ce document sera complété au fur et à mesure des
échanges, une rubrique à la fois.
