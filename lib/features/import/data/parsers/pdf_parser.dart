import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/import/data/import_parser.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsed_tournee.dart';
import 'package:genesis_picking/features/import/data/parsers/pdf_photo_extractor.dart';
import 'package:genesis_picking/features/import/data/parsers/pdf_text_extractor.dart';

/// Analyseur PDF — calibré sur la "Feuille de préparation globale"
/// réellement exportée par myFulfillment (Univers Parapharmacie), en
/// exécutant [PdfTextExtractor] sur de vrais fichiers fournis pour
/// calibrage (`pickinglist--2954.pdf`, `pickinglist--3139.pdf`) plutôt
/// qu'en supposant sa sortie.
///
/// Structure réelle observée (confirmée en exécutant l'extracteur, pas
/// devinée) :
/// - Aucun numéro de tournée dans le texte du PDF lui-même : le document
///   ne contient qu'un titre "Feuille de préparation globale". Le numéro
///   est porté par le NOM DU FICHIER (ex. "pickinglist--2954.pdf").
/// - `syncfusion_flutter_pdf` insère un caractère NUL (code U+0000) avant
///   chaque caractère du texte extrait de ce document précis (police
///   embarquée à codes deux octets, artefact confirmé en exécutant
///   l'extracteur sur les deux fichiers réels — un octet de tête à zéro
///   mal filtré par la bibliothèque). Sans ce nettoyage, aucune ligne ne
///   correspond plus à rien : voir [_nettoyerTexte].
/// - Une fois nettoyées, quantité, emplacement (optionnel) et références
///   `réf1 - réf2` sont chacun sur leur PROPRE ligne (pas combinés sur une
///   seule ligne), suivis d'une ou plusieurs lignes de nom de produit. Le
///   motif combiné (une seule ligne "qté emplacement réf1 - réf2") reste
///   également reconnu, au cas où un export produirait un jour cette forme.
/// - `réf2` peut contenir des caractères hors `\w` (ex. "91858 - *04") :
///   volontairement capturé en `\S*`, pas `\w*`.
/// - Chaque page répète l'en-tête ("Qté", "Emplacement", "Produit" — sur
///   3 lignes séparées) et un pied de page "Page X/Y" : ignorés.
///
/// IMPORTANT — deux méthodes d'extraction de `PdfTextExtractor`, deux
/// segmentations DIFFÉRENTES du même texte, vérifié en exécutant les
/// deux sur les fichiers réels : [PdfTextExtractor.extractText] découpe
/// quantité / emplacement / référence chacun sur sa propre ligne (ce que
/// le parsing ci-dessus attend), alors que
/// [PdfTextExtractor.extractTextLinePositions] regroupe emplacement et
/// référence sur une même ligne. Le parsing du contenu utilise donc
/// exclusivement `extractText` (déjà calibré et testé) ; les positions ne
/// servent QU'à retrouver la ligne "quantité seule" de chaque produit,
/// jamais à reconstruire le texte.
///
/// Photo produit : `syncfusion_flutter_pdf` n'expose AUCUNE extraction
/// d'image d'un PDF existant, dans aucune version (vérifié sur son
/// changelog complet) — seulement l'écriture d'images dans un PDF qu'on
/// crée. La colonne photo à gauche de "Qté" est pourtant bien réelle
/// (confirmé en inspectant les octets bruts du PDF : 46 images JPEG
/// embarquées dans `pickinglist--3139.pdf`). Solution : [PdfPhotoExtractor]
/// (`pdfrx`, moteur pdfium) rend la zone de page correspondant à chaque
/// ligne produit — délimitée par la position réelle (haut/gauche, en
/// points PDF) de la ligne "quantité" de ce produit et de la suivante —
/// puis encode le rendu en JPEG. Jamais une image inventée : si le
/// nombre de lignes "quantité seule" positionnées ne correspond pas
/// exactement au nombre de produits détectés par le parsing, ou si le
/// rendu d'une zone échoue, cette ou ces photos restent `null` plutôt
/// que d'être associées au hasard.
///
/// Sur une picking list volumineuse (plusieurs centaines de produits),
/// ce rendu page par page devient le poste le plus lent de tout l'import
/// (vérifié : 277 produits → ~23s sur `pickinglist--3066.pdf`, fourni par
/// l'utilisateur comme exemple réel de liste longue). Pour ne jamais
/// geler l'écran d'import pendant cette attente, le rendu — quand il
/// s'agit bien du VRAI moteur [PdfrxPhotoExtractor], jamais un
/// extracteur de test injecté (voir [_associerPhotos]) — est déporté
/// dans un isolate séparé via [compute] ; vérifié sur ce même fichier
/// réel que le résultat (produits détectés, photos associées) est
/// strictement identique avec ou sans ce déport, avant d'être livré ici.
class PdfParser implements ImportParser {
  PdfParser({
    required PdfTextExtractor textExtractor,
    PdfPhotoExtractor? photoExtractor,
    RegExp? ligneNumeroTourneePattern,
    RegExp? ligneProduitCombineePattern,
  }) : _textExtractor = textExtractor,
       _photoExtractor = photoExtractor ?? PdfrxPhotoExtractor(),
       _ligneNumeroTourneePattern =
           ligneNumeroTourneePattern ??
           RegExp(
             r'tourn[ée]e\s*n?°?\s*:?\s*([A-Za-z0-9\-\/]+)',
             caseSensitive: false,
           ),
       _ligneProduitCombineePattern =
           ligneProduitCombineePattern ??
           RegExp(
             r'^(?<qte>\d+)\s+(?:(?<emplacement>[A-Za-z]{1,3}\d{1,3})\s+)?'
             r'(?<ref1>\S+)\s*-\s*(?<ref2>\S*)\s*$',
           );

  final PdfTextExtractor _textExtractor;
  final PdfPhotoExtractor _photoExtractor;
  final RegExp _ligneNumeroTourneePattern;

  /// Toute la déclaration d'un produit (qté, emplacement optionnel, réfs)
  /// sur une seule ligne — forme historique, conservée en repli.
  final RegExp _ligneProduitCombineePattern;

  static final RegExp _ligneQteSeule = RegExp(r'^\d+$');
  static final RegExp _ligneEmplacementSeule = RegExp(r'^[A-Za-z]{1,3}\d{1,3}$');
  static final RegExp _ligneRefSeule = RegExp(r'^(?<ref1>\S+)\s*-\s*(?<ref2>\S*)$');

  static final RegExp _entete = RegExp(
    r'^qt[ée]$|^emplacement$|^produit$|^qt[ée]\s+emplacement\s+produit$',
    caseSensitive: false,
  );
  static final RegExp _titre = RegExp(
    r'^feuille de pr[ée]paration',
    caseSensitive: false,
  );
  static final RegExp _piedDePage = RegExp(
    r'^page\s+\d+\s*/\s*\d+$',
    caseSensitive: false,
  );

  /// Marge gauche de la colonne photo (points PDF) — la limite droite,
  /// elle, est dérivée dynamiquement de la position réelle de chaque
  /// ligne "quantité", jamais figée en dur.
  static const double _margeGauchePhoto = 10;
  static const double _margeAvantColonneQte = 3;
  // Marges asymétriques, ajustées par vérification visuelle : la photo
  // d'une ligne se trouve presque au niveau (voire légèrement en dessous)
  // de sa ligne "quantité", jamais nettement au-dessus — une marge haute
  // trop généreuse capte un filet de la photo de la ligne PRÉCÉDENTE,
  // une marge basse trop courte capte un filet de la ligne SUIVANTE.
  static const double _margeHaut = 2;
  static const double _margeBas = 12;
  static const double _hauteurMaxSiDerniereLigneDePage = 150;

  @override
  ImportFormat get format => ImportFormat.pdf;

  @override
  Future<ParsedTournee> parse(
    ImportSource source, {
    void Function(int done, int total)? onProgress,
  }) async {
    final String texteBrut;
    try {
      texteBrut = await _textExtractor.extractText(source.bytes);
    } catch (error) {
      throw ImportStructureException(
        'Le fichier "${source.fileName}" n\'a pas pu être lu comme un PDF '
        '(fichier corrompu ou protégé).',
      );
    }

    if (texteBrut.trim().isEmpty) {
      throw const ImportStructureException(
        'Aucun texte n\'a pu être extrait du PDF (page scannée sans '
        'couche texte ?).',
      );
    }

    final lignes = _nettoyerTexte(texteBrut)
        .split('\n')
        .map((l) => l.trim())
        .toList();

    String? numeroTournee;
    final produits = <ParsedProduit>[];

    int? qteCourante;
    String? emplacementCourant;
    String? refCourante;
    String nomCourant = '';
    int ligneSourceCourante = 0;

    void enregistrerProduitEnCours() {
      if (qteCourante == null) return;
      produits.add(
        ParsedProduit(
          ligneSource: ligneSourceCourante,
          nom: nomCourant.trim().isEmpty ? null : nomCourant.trim(),
          description: refCourante,
          emplacement: emplacementCourant,
          quantiteDemandee: qteCourante,
        ),
      );
      qteCourante = null;
      emplacementCourant = null;
      refCourante = null;
      nomCourant = '';
    }

    for (var i = 0; i < lignes.length; i++) {
      final ligne = lignes[i];
      if (ligne.isEmpty) continue;

      // Lignes structurelles répétées sur chaque page : jamais un nom de
      // produit, jamais un numéro de tournée.
      if (_entete.hasMatch(ligne) ||
          _titre.hasMatch(ligne) ||
          _piedDePage.hasMatch(ligne)) {
        continue;
      }

      if (numeroTournee == null) {
        final matchTournee = _ligneNumeroTourneePattern.firstMatch(ligne);
        if (matchTournee != null) {
          numeroTournee = matchTournee.group(1);
          continue;
        }
      }

      // Forme combinée : "qté [emplacement] réf1 - réf2" en une ligne —
      // déclare entièrement un nouveau produit d'un coup.
      final matchCombine = _ligneProduitCombineePattern.firstMatch(ligne);
      if (matchCombine != null) {
        enregistrerProduitEnCours();
        qteCourante = int.tryParse(matchCombine.namedGroup('qte') ?? '');
        emplacementCourant = matchCombine.namedGroup('emplacement');
        refCourante = _combineRefs(
          matchCombine.namedGroup('ref1'),
          matchCombine.namedGroup('ref2'),
        );
        nomCourant = '';
        ligneSourceCourante = i + 1;
        continue;
      }

      // Forme réelle observée : quantité seule sur sa ligne — un nouveau
      // produit démarre, mais emplacement/référence suivent sur les
      // lignes suivantes (voir plus bas). On ne déclenche ce démarrage
      // que si le produit précédent avait déjà sa référence (sinon un
      // fragment de nom purement numérique pourrait être mal interprété).
      if (_ligneQteSeule.hasMatch(ligne) &&
          (qteCourante == null || refCourante != null)) {
        enregistrerProduitEnCours();
        qteCourante = int.tryParse(ligne);
        emplacementCourant = null;
        refCourante = null;
        nomCourant = '';
        ligneSourceCourante = i + 1;
        continue;
      }

      // En attente de l'emplacement (optionnel) ou de la référence du
      // produit en cours.
      if (qteCourante != null && refCourante == null) {
        if (emplacementCourant == null && _ligneEmplacementSeule.hasMatch(ligne)) {
          emplacementCourant = ligne;
          continue;
        }
        final matchRef = _ligneRefSeule.firstMatch(ligne);
        if (matchRef != null) {
          refCourante = _combineRefs(
            matchRef.namedGroup('ref1'),
            matchRef.namedGroup('ref2'),
          );
          continue;
        }
      }

      // Ni une ligne de produit, ni une ligne structurelle : c'est la
      // suite du nom du produit en cours (nom réparti sur plusieurs
      // lignes).
      if (qteCourante != null) {
        nomCourant = nomCourant.isEmpty ? ligne : '$nomCourant $ligne';
      }
    }
    enregistrerProduitEnCours();

    await _associerPhotos(
      source: source,
      produits: produits,
      onProgress: onProgress,
    );

    return ParsedTournee(
      numeroTournee: numeroTournee ?? _numeroDepuisNomFichier(source.fileName),
      produits: produits,
    );
  }

  /// Rend et associe la photo de chaque produit à partir de la position
  /// réelle de sa ligne "quantité seule" — jamais si le nombre de telles
  /// lignes positionnées ne correspond pas exactement au nombre de
  /// produits détectés par le parsing (voir docstring de classe : mieux
  /// vaut aucune photo qu'une mal associée).
  Future<void> _associerPhotos({
    required ImportSource source,
    required List<ParsedProduit> produits,
    void Function(int done, int total)? onProgress,
  }) async {
    if (produits.isEmpty) return;

    final List<PdfTextLinePosition> positions;
    try {
      positions = await _textExtractor.extractTextLinePositions(source.bytes);
    } catch (error) {
      AppLogger.warning(
        'Positions de texte indisponibles pour "${source.fileName}" : '
        '$error — import conservé sans photo.',
        tag: 'PdfParser',
      );
      return;
    }

    final ancres = <({int pageIndex, double top, double left})>[];
    for (final p in positions) {
      final nettoye = _nettoyerTexte(p.text).trim();
      if (_ligneQteSeule.hasMatch(nettoye)) {
        ancres.add((pageIndex: p.pageIndex, top: p.top, left: p.left));
      }
    }

    if (ancres.length != produits.length) {
      AppLogger.warning(
        'Photos produit non associées : ${ancres.length} positions "quantité" '
        'pour ${produits.length} produits (source "${source.fileName}").',
        tag: 'PdfParser',
      );
      return;
    }

    // Hauteur de ligne "typique" — médiane des écarts réels entre deux
    // lignes "quantité" consécutives SUR LA MÊME PAGE. Utilisée pour la
    // dernière ligne de chaque page plutôt que le pied de page : une page
    // partiellement remplie (dernière page d'un document, souvent moins
    // chargée) laisse un grand blanc avant le pied de page — s'étirer
    // jusque-là capturait surtout ce blanc plutôt que la photo (vérifié
    // visuellement : "Marvis Dentifrice", seul produit de fin de page,
    // donnait une image à 84 % de blanc).
    final ecarts = <double>[];
    for (var i = 0; i + 1 < ancres.length; i++) {
      if (ancres[i + 1].pageIndex == ancres[i].pageIndex) {
        ecarts.add(ancres[i + 1].top - ancres[i].top);
      }
    }
    final hauteurLigneTypique = ecarts.isEmpty
        ? _hauteurMaxSiDerniereLigneDePage
        : (ecarts..sort())[ecarts.length ~/ 2];

    final regions = <PdfPhotoRegion>[];
    for (var i = 0; i < ancres.length; i++) {
      final ancre = ancres[i];
      final suivante = i + 1 < ancres.length ? ancres[i + 1] : null;
      final bottom = (suivante != null && suivante.pageIndex == ancre.pageIndex)
          ? suivante.top - _margeBas
          : ancre.top + hauteurLigneTypique - _margeBas;

      regions.add(
        PdfPhotoRegion(
          pageIndex: ancre.pageIndex,
          top: ancre.top - _margeHaut,
          bottom: bottom,
          left: _margeGauchePhoto,
          right: ancre.left - _margeAvantColonneQte,
        ),
      );
    }

    try {
      // Le vrai moteur de rendu part dans un isolate séparé (voir la
      // docstring de classe) ; un extracteur injecté par un test reste
      // appelé directement — un objet de test ne survit pas la traversée
      // d'isolate, et n'a de toute façon pas ce coût à éviter. Avec
      // [onProgress], le déport se fait via [_rendreDansUnIsolateAvecProgres]
      // (canal de communication ouvert, pour recevoir une progression au
      // fur et à mesure) plutôt que [compute] (qui ne renvoie qu'un
      // résultat final, sans rien entre-temps).
      final resultats = _photoExtractor is PdfrxPhotoExtractor
          ? onProgress != null
              ? await _rendreDansUnIsolateAvecProgres(
                  source.bytes,
                  regions,
                  onProgress,
                )
              : await compute(
                  _rendreDansUnIsolate,
                  _EntreeRenduPhotos(source.bytes, regions),
                )
          : await _photoExtractor.extractPhotos(
              source.bytes,
              regions,
              onProgress: onProgress,
            );
      for (var i = 0; i < resultats.length && i < produits.length; i++) {
        final bytes = resultats[i];
        if (bytes == null) continue;
        produits[i] = ParsedProduit(
          ligneSource: produits[i].ligneSource,
          nom: produits[i].nom,
          description: produits[i].description,
          emplacement: produits[i].emplacement,
          quantiteDemandee: produits[i].quantiteDemandee,
          imageUrl: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        );
      }
    } catch (error) {
      // Le rendu des photos ne doit jamais faire échouer tout l'import :
      // les produits restent valides, simplement sans image.
      AppLogger.warning(
        'Extraction des photos produit impossible pour '
        '"${source.fileName}" : $error',
        tag: 'PdfParser',
      );
    }
  }

  String? _combineRefs(String? ref1, String? ref2) {
    final r1 = ref1 ?? '';
    final r2 = ref2 ?? '';
    if (r1.isEmpty) return null;
    return r2.isEmpty ? r1 : '$r1 - $r2';
  }

  /// Retire les caractères NUL insérés par `syncfusion_flutter_pdf` avant
  /// chaque caractère sur ce document (voir la note de calibrage en tête
  /// de fichier). Sans effet sur un texte qui n'en contient pas.
  String _nettoyerTexte(String texte) {
    return texte.replaceAll(String.fromCharCode(0), '');
  }

  /// Le PDF ne contient aucun numéro de tournée en texte (uniquement le
  /// titre "Feuille de préparation globale") : le numéro réel est porté
  /// par le nom du fichier exporté (ex. "pickinglist--2954.pdf").
  String? _numeroDepuisNomFichier(String fileName) {
    final base = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final match = RegExp(r'(\d+)$').firstMatch(base);
    if (match != null) return 'CMD-${match.group(1)}';
    return base.isEmpty ? null : base;
  }
}

/// Message transmissible à [compute] (donnée pure, aucune méthode) —
/// [Uint8List] et une liste de [PdfPhotoRegion] (elles-mêmes de simples
/// nombres) traversent la frontière d'isolate sans problème.
class _EntreeRenduPhotos {
  const _EntreeRenduPhotos(this.bytes, this.regions);
  final Uint8List bytes;
  final List<PdfPhotoRegion> regions;
}

/// Fonction top-level requise par [compute] : reconstruit un
/// [PdfrxPhotoExtractor] frais À L'INTÉRIEUR de l'isolate (un objet ne
/// traverse jamais la frontière, seules des données pures le peuvent) et
/// y exécute le rendu — voir la docstring de [PdfParser] pour pourquoi.
Future<List<Uint8List?>> _rendreDansUnIsolate(_EntreeRenduPhotos entree) {
  return PdfrxPhotoExtractor().extractPhotos(entree.bytes, entree.regions);
}

/// Message de départ transmis à l'isolate — [sendPort] est le seul moyen
/// pour l'isolate de communiquer EN COURS DE ROUTE (progression), pas
/// seulement à la toute fin comme avec [compute].
class _MessageDepart {
  const _MessageDepart(this.bytes, this.regions, this.sendPort);
  final Uint8List bytes;
  final List<PdfPhotoRegion> regions;
  final SendPort sendPort;
}

/// Un seul type de message dans les deux sens (progression, résultat
/// final, erreur) — champs nullables plutôt qu'une hiérarchie de classes,
/// pour rester simple ; un seul des trois groupes de champs est renseigné
/// à la fois.
class _MessageIsolate {
  const _MessageIsolate.progres(int done, int total)
      : this._(done: done, total: total);
  const _MessageIsolate.resultat(List<Uint8List?> resultats)
      : this._(resultats: resultats);
  const _MessageIsolate.erreur(String erreur) : this._(erreur: erreur);
  const _MessageIsolate._({this.done, this.total, this.resultats, this.erreur});

  final int? done;
  final int? total;
  final List<Uint8List?>? resultats;
  final String? erreur;
}

/// Point d'entrée de l'isolate (voir [Isolate.spawn]) : reconstruit un
/// [PdfrxPhotoExtractor] frais (même raison que [_rendreDansUnIsolate])
/// et renvoie une progression après CHAQUE région rendue, plutôt qu'un
/// seul message final — c'est ce qui permet à l'écran d'import d'afficher
/// un pourcentage réel sur une tournée volumineuse.
void _entreePointIsolate(_MessageDepart message) async {
  try {
    final resultats = await PdfrxPhotoExtractor().extractPhotos(
      message.bytes,
      message.regions,
      onProgress: (done, total) {
        message.sendPort.send(_MessageIsolate.progres(done, total));
      },
    );
    message.sendPort.send(_MessageIsolate.resultat(resultats));
  } catch (error) {
    message.sendPort.send(_MessageIsolate.erreur(error.toString()));
  }
}

/// Variante de [_rendreDansUnIsolate] avec progression en direct — voir
/// [_entreePointIsolate]. [onProgress] est appelé sur l'isolate APPELANT
/// (celui de l'écran), jamais depuis l'isolate de rendu : les messages
/// reçus via [ReceivePort] sont déjà de retour ici avant tout appel.
Future<List<Uint8List?>> _rendreDansUnIsolateAvecProgres(
  Uint8List bytes,
  List<PdfPhotoRegion> regions,
  void Function(int done, int total) onProgress,
) async {
  final receivePort = ReceivePort();
  final completer = Completer<List<Uint8List?>>();
  Isolate? isolate;

  final subscription = receivePort.listen((message) {
    if (message is! _MessageIsolate) return;
    if (message.resultats != null) {
      if (!completer.isCompleted) completer.complete(message.resultats);
    } else if (message.erreur != null) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(message.erreur!));
      }
    } else if (message.done != null && message.total != null) {
      onProgress(message.done!, message.total!);
    }
  });

  try {
    isolate = await Isolate.spawn(
      _entreePointIsolate,
      _MessageDepart(bytes, regions, receivePort.sendPort),
    );
    return await completer.future;
  } finally {
    await subscription.cancel();
    receivePort.close();
    isolate?.kill(priority: Isolate.immediate);
  }
}
