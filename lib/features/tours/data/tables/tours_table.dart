import 'package:drift/drift.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Table des tournées.
///
/// Contient exactement les champs demandés par la Directive Module 3 :
/// identifiant, numéro, préparateur assigné, dates, état, nombre total de
/// produits, progression, date de synchronisation.
///
/// Ne contient aucune donnée produit (voir [TourProductLinesTable]) ni
/// aucune logique de validation — cette table ne fait que persister
/// l'état d'avancement global d'une tournée.
class ToursTable extends Table {
  TextColumn get id => text()();

  TextColumn get numeroTournee => text()();

  /// Référence vers `UsersTable.id` (Module 2) — pas de contrainte de
  /// clé étrangère Drift déclarée ici volontairement : les tournées
  /// peuvent être créées avant que l'intégration complète avec la
  /// gestion des comptes ne soit approfondie (voir README, "limites
  /// connues").
  TextColumn get preparateurId => text()();

  DateTimeColumn get dateCreation => dateTime()();

  /// Nulle tant que la tournée n'a pas encore été téléchargée localement.
  DateTimeColumn get dateTelechargement => dateTime().nullable()();

  TextColumn get statut => textEnum<TourStatus>()();

  TextColumn get etatSynchronisation => textEnum<TourSyncState>()();

  IntColumn get nombreTotalProduits => integer()();

  /// Nombre de produits ayant déjà un état final. Simple compteur en
  /// Module 3 : la logique qui l'incrémente réellement produit par
  /// produit appartient au Module 4. Sert ici uniquement à permettre la
  /// reprise ("l'application doit savoir exactement où elle en était").
  IntColumn get produitsTraites => integer().withDefault(const Constant(0))();

  DateTimeColumn get dateSynchronisation => dateTime().nullable()();

  /// Début RÉEL du picking (premier passage à `enCours`, voir
  /// `TourService.startOrResume`) — distinct de [dateTelechargement] : un
  /// préparateur peut télécharger une tournée bien avant de commencer à
  /// la préparer. Jamais réécrit lors d'une reprise (fermer puis rouvrir
  /// l'appli en cours de route), pour que la durée mesurée reste le vrai
  /// temps de travail, pas le temps entre deux ouvertures d'écran.
  DateTimeColumn get dateDebut => dateTime().nullable()();

  /// Fin réelle du picking (passage à `terminee`, voir
  /// `TourService.completeTour`) — avec [dateDebut], permet de mesurer la
  /// durée effective d'une tournée (voir `Tour.dureeEcoulee`).
  DateTimeColumn get dateFin => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
