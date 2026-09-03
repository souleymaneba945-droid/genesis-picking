# GENESIS PICKING — Moteur d'import des picking lists

Remplace les données de démonstration par un vrai moteur d'import, indépendant du
format, capable de recevoir une vraie tournée dès aujourd'hui (PDF) et prêt à
accueillir d'autres formats sans modification de l'architecture.

---

## 0. Contexte — réponse à la question posée

**Aujourd'hui, la seule méthode réellement disponible est le PDF.** L'intégration
API avec myFulfillment (BoostMyShop) est bloquée par une erreur de session PHP sur
l'export et l'absence des réglages API/Intégrations dans le compte — BoostMyShop
support doit être recontacté pour lever ce blocage. Un export CSV existe déjà côté
ERP pour d'autres usages (analyse de mouvements de stock), mais rien ne confirme
qu'un export CSV de la picking list elle-même soit disponible.

**Conséquence pour ce livrable** : le `PDFParser` est la seule implémentation
calibrée sur un besoin réel. Les analyseurs CSV, Excel et JSON sont RÉELLEMENT
fonctionnels (pas des stubs), mais leur format de colonnes/champs exact reste une
hypothèse raisonnable non calibrée sur un vrai fichier — voir section 6, "Prochaine
étape".

---

## 1. Architecture

```
lib/features/import/
├── import_providers.dart
├── data/
│   ├── tables/import_history_table.dart
│   ├── import_format.dart          # ImportFormat (pdf, excel, csv, json, api)
│   ├── import_source.dart          # ImportSource (octets + nom de fichier)
│   ├── parsed_tournee.dart         # ParsedTournee / ParsedProduit (avant validation)
│   ├── import_parser.dart          # Interface ImportParser + ImportStructureException
│   ├── import_report.dart          # ImportReport, ImportIssue
│   ├── import_repository.dart      # Interface
│   ├── drift_import_repository.dart
│   └── parsers/
│       ├── pdf_text_extractor.dart # Extraction de texte (Syncfusion)
│       ├── pdf_parser.dart         # PDFParser — RÉEL, calibrage requis
│       ├── csv_parser.dart         # CSVParser — RÉEL
│       ├── excel_parser.dart       # ExcelParser — RÉEL
│       └── json_parser.dart        # JSONParser — RÉEL
├── domain/
│   ├── import_validator.dart       # ImportValidator
│   └── import_engine.dart          # ImportEngine
└── presentation/
    └── admin_import_screen.dart    # Écran d'import (Administrateur)

lib/features/tours/data/tour_remote_source.dart  [MODIFIÉ] DemoTourRemoteSource
                                                    remplacée par NoTourRemoteSource
lib/features/tours/tours_providers.dart          [MODIFIÉ] branchement de la
                                                    nouvelle source
lib/features/administration/presentation/admin_dashboard_screen.dart  [MODIFIÉ]
                                                    accès à l'écran d'import

test/features/import/
├── import_validator_test.dart
├── csv_parser_test.dart
├── json_parser_test.dart
├── import_engine_test.dart
├── fake_import_parser.dart
└── fake_import_repository.dart
```

### `ImportEngine` : indépendant du format, par construction
```
ImportEngine
│
├── PDFParser    (réel, calibrage requis)
├── ExcelParser  (réel, non calibré)
├── CSVParser    (réel, non calibré)
├── JSONParser   (réel, non calibré)
└── (futur)      ajouter un format = ajouter une entrée au registre de
                  ImportEngine, sans toucher à cette classe ni à
                  ImportValidator, ImportRepository, ou l'écran
```
Chaque parser implémente `ImportParser` (une seule méthode : `parse(ImportSource) →
ParsedTournee`) et ne connaît ni la validation, ni la persistance, ni l'historique.
`ImportEngine` ne contient aucune ligne spécifique à un format — ajouter le
sixième format de la question posée ("Autre format") ou l'option 5 ("API") se
résume à écrire un nouveau `ImportParser` et l'enregistrer dans
`import_providers.dart`.

### Le cas "API" (option 5) : ce n'est pas un nouveau parser, c'est un nouveau déclencheur
Une intégration API n'ajouterait probablement pas de nouvelle logique de PARSING
(le logiciel de gestion enverrait déjà des données structurées, proches du format
JSON) : elle ajouterait un nouveau POINT D'ENTRÉE qui appelle
`ImportEngine.import(format: ImportFormat.json, ...)` directement avec les octets
reçus, sans passer par un écran de sélection de fichier. C'est exactement pour ça
que `ImportSource` est une abstraction pure (octets + nom), indépendante de sa
provenance (fichier choisi à la main aujourd'hui, requête API demain).

### Persistance directe via `TourRepository` (Module 3, inchangé)
Contrairement au modèle initial du Module 3 ("Disponible" → téléchargement séparé
par le préparateur), un import réussi crée directement la tournée à l'état
"Téléchargée" : l'Administrateur qui importe une picking list a, par définition,
déjà tout son contenu — il n'y a rien à "télécharger" séparément dans ce contexte
d'application à base locale partagée. `TourRepository.saveDownloadedTour` (déjà
atomique et idempotent depuis le Module 3) n'a nécessité AUCUNE modification.

### Identifiant déterministe : la clé de la reprise et de l'anti-doublon
`ImportEngine._deterministicTourId()` dérive l'identifiant de la tournée
directement de son numéro (ex. `T-2026-0001` → `import-t-2026-0001`), plutôt que
de générer un UUID aléatoire à chaque tentative. Conséquence directe :
- **Reprise** (Directive) : si l'import est interrompu avant la persistance (crash,
  fermeture de l'app), aucune tournée n'a été créée ; relancer le MÊME import
  retombe sur le même identifiant et le crée normalement — rien à "reprendre"
  activement, la reprise est un sous-produit de l'idempotence.
- **Doublons** (Directive) : réimporter par erreur (ou volontairement) le même
  fichier détecte que la tournée existe déjà (`estTeleChargeeLocalement`) et ne
  duplique rien — `ImportReport.dejaImportee` le signale explicitement à
  l'Administrateur plutôt que de faire silencieusement comme si de rien n'était.

### Validation : erreurs bloquantes vs avertissements (choix assumé)
- Numéro de tournée manquant, ou aucun produit → **erreur bloquante** (rien n'est
  persisté).
- Nom, emplacement ou quantité manquant/invalide sur un produit → **erreur
  bloquante**. Dans un contexte de pharmacie, une quantité ou un emplacement faux
  est plus dangereux qu'un import refusé — mieux vaut corriger la source.
- Image manquante → **avertissement seulement** : le picking reste possible sans
  photo (Document UX/UI : l'image aide, elle n'est pas indispensable à l'action).

### "Ne jamais planter" — trois niveaux de filet
1. Chaque `ImportParser` ne lève que des `ImportStructureException` pour un
   problème de structure connu (fichier vide, colonnes manquantes...).
2. `ImportEngine` capture aussi toute exception IMPRÉVUE d'un parser (`catch
   (error)` générique) et la transforme en rapport d'échec.
3. `ImportValidator` ne lève jamais d'exception : toujours une liste
   d'`ImportIssue`, jamais un `throw`.

---

## 2. Migration de la base locale

| Schéma | Ajout |
|---|---|
| v6 | (Module 6 — Synchronisation) |
| v7 | `ImportHistoryTable` (ce livrable) |

Aucune tournée, compte, état de collecte ou demande coursier existant n'est
affecté. `DemoTourRemoteSource` a été retirée du code (pas une migration de
données : elle ne stockait jamais rien en base, uniquement en mémoire).

---

## 3. Dépendances ajoutées

| Paquet | Rôle |
|---|---|
| `csv` | Analyse des fichiers CSV |
| `excel` | Lecture des classeurs .xlsx |
| `syncfusion_flutter_pdf` | Extraction de texte PDF — licence communautaire gratuite pour les structures sous certains seuils de revenus/effectifs ; à réévaluer si l'usage dépasse ces seuils (conditions exactes sur le site Syncfusion, à vérifier avant un déploiement commercial à grande échelle). |
| `file_picker` | Sélection d'un fichier réel depuis l'écran d'import Administrateur |

---

## 4. Tests réalisés

Conformément à la liste de la Directive :

- **Petit fichier** — `import_engine_test.dart` : tournée à 2 produits, import
  réussi, historique enregistré.
- **Gros fichier** — `import_validator_test.dart` et `import_engine_test.dart` :
  400 à 500 produits traités sans erreur.
- **Fichier incomplet** — `import_engine_test.dart` : produit sans quantité →
  refusé sans rien persister ; image manquante seule → accepté avec avertissement.
- **Doublons** — réimporter la même tournée ne déclenche qu'une seule écriture
  réelle, `ImportReport.dejaImportee` le signale.
- **Erreur de structure** — testée à trois niveaux : erreur `ImportStructureException`
  connue, erreur totalement imprévue, format non enregistré — jamais d'exception
  qui remonte à l'appelant.
- **Import interrompu** — simulé (échec avant persistance), puis reprise par
  réimport du même fichier : aboutit normalement, aucune duplication.

Tests complémentaires sur les analyseurs eux-mêmes (`csv_parser_test.dart`,
`json_parser_test.dart`) : colonnes/alias reconnus, fichier vide, structure
invalide, 400 lignes.

### Même limite technique que tous les modules précédents
`flutter pub get` (nouvelles dépendances), `flutter analyze`, `flutter test` et
`flutter run` n'ont pas pu être exécutés dans cet environnement de conception
(absence du SDK Flutter/Dart, et `pub.dev` non accessible depuis ce sandbox). Le
code a été écrit et relu avec rigueur, mais je le signale explicitement.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

---

## 5. Checklist de validation

- [ ] Un vrai PDF de picking list myFulfillment s'importe avec succès.
- [ ] Le rapport d'import affiche correctement les produits détectés, les erreurs
      et les avertissements.
- [ ] Réimporter le même PDF ne crée pas de doublon.
- [ ] Un PDF corrompu ou vide produit un message clair, jamais un crash.
- [ ] Un produit sans quantité ou sans emplacement bloque l'import avec un message
      explicite.
- [ ] Un produit sans image seul n'empêche pas l'import.
- [ ] L'historique des imports enregistre bien chaque tentative (réussie ou non).

---

## 6. Prochaine étape (au-delà de ce livrable)

1. **Calibrage du `PDFParser`** sur un vrai fichier myFulfillment : ajuster
   `_ligneNumeroTourneePattern` et `_ligneProduitPattern` (les deux seuls points de
   variation du fichier) une fois un exemplaire réel disponible.
2. **Relancer BoostMyShop** (help@boostmyshop.com) pour débloquer l'accès
   API/Intégrations — c'est la vraie cible à moyen terme, pas le PDF.
3. Si un export CSV de picking list s'avère possible côté myFulfillment, vérifier
   ses en-têtes réels contre les alias déjà reconnus par `CsvParser` et les
   compléter si besoin — sans toucher à `ImportEngine`.
4. Le jour où l'API est débloquée : écrire un `ApiTourRemoteSource` (ou un nouveau
   déclencheur appelant `ImportEngine` directement avec `ImportFormat.json`), sans
   modifier `ImportEngine`, `ImportValidator`, ni l'écran d'import existant.
