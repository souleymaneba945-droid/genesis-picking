import 'package:drift/drift.dart';

/// Table des lignes produits d'une tournée téléchargée.
///
/// Stocke UNIQUEMENT les données brutes déjà fournies par le logiciel de
/// gestion (voir Directive Architecture fonctionnelle, chapitre 2 :
/// "l'application ne gère jamais le catalogue produits"), nécessaires à
/// l'intégrité du téléchargement et au calcul de [ToursTable.nombreTotalProduits].
///
/// Ne comporte AUCUN champ d'état de collecte ("à récupérer", "collecté",
/// "introuvable"...) : cet ajout appartient explicitement au Module 4
/// (Picking), qui étendra cette table sans avoir à modifier ce fichier —
/// même logique de modularité que le reste du projet.
class TourProductLinesTable extends Table {
  TextColumn get id => text()();

  TextColumn get tourId => text()();

  /// Position dans la tournée telle que fournie par le logiciel de
  /// gestion — préserve l'ordre d'origine, sans opinion de tri propre à
  /// l'application.
  IntColumn get ordre => integer()();

  TextColumn get nom => text()();
  TextColumn get description => text().nullable()();

  /// URL ou chemin de l'image du produit, tel que fourni par le logiciel
  /// de gestion — jamais générée ni modifiée par l'application.
  TextColumn get imageUrl => text().nullable()();

  IntColumn get quantiteDemandee => integer()();
  TextColumn get emplacement => text()();

  @override
  Set<Column> get primaryKey => {id};
}
