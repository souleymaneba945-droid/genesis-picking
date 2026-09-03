import 'package:drift/drift.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Table des demandes envoyées par un préparateur à un coursier pour un
/// produit introuvable.
///
/// Toutes les colonnes exigées par la Directive Module 5 sont présentes :
/// identifiant, préparateur, coursier, tournée, produit, quantité
/// demandée, emplacement, date/heure de création, état — ainsi que les
/// horodatages d'historique (acceptation, traitement, clôture).
///
/// La quantité et l'emplacement sont dupliqués depuis
/// `TourProductLinesTable` (Module 3) au moment de la création : c'est un
/// instantané volontaire, pour que l'historique d'une demande reste exact
/// même si la ligne produit d'origine changeait par ailleurs.
class CourierRequestsTable extends Table {
  TextColumn get id => text()();

  TextColumn get preparateurId => text()();
  TextColumn get coursierId => text()();
  TextColumn get tourId => text()();
  TextColumn get productLineId => text()();

  IntColumn get quantiteDemandee => integer()();
  TextColumn get emplacement => text()();

  // Instantané du produit au moment de la création (nom, description/SKU,
  // photo) — même principe que quantiteDemandee/emplacement ci-dessus, mais
  // indispensable ici pour une raison supplémentaire : contrairement au
  // préparateur (qui a toujours la tournée téléchargée localement), le
  // coursier ne télécharge jamais de tournée. Sans cet instantané, une
  // demande reçue via Firestore sur l'appareil du coursier n'a aucun moyen
  // de retrouver le nom/la description/la photo du produit — la jointure
  // locale vers `TourProductLinesTable` échoue silencieusement (ligne
  // absente de sa base). Nullable : absent sur les lignes créées avant
  // cette colonne (schéma < 9), auquel cas la jointure locale reste le
  // repli (voir `CourierService`).
  TextColumn get produitNom => text().nullable()();
  TextColumn get produitDescription => text().nullable()();
  TextColumn get produitImageUrl => text().nullable()();

  DateTimeColumn get dateCreation => dateTime()();
  TextColumn get etat => textEnum<CourierRequestStatus>()();

  TextColumn get resultat => textEnum<CourierRequestResult>().nullable()();

  DateTimeColumn get dateAcceptation => dateTime().nullable()();
  DateTimeColumn get dateTraitement => dateTime().nullable()();
  DateTimeColumn get dateCloture => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
