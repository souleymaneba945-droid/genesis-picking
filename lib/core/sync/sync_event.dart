import 'package:drift/drift.dart';

/// États possibles d'une opération en attente de synchronisation.
///
/// Correspond exactement au vocabulaire de la Directive Module 6 : En
/// attente ([pending]), En cours ([inProgress]), Synchronisé ([synced]),
/// Échec ([failed]), À réessayer ([retrying]). Les noms internes restent
/// ceux posés au Module 1 (anglais) pour ne rien casser côté stockage —
/// seule la présentation à l'écran utilise les libellés français exacts
/// de la Directive (voir `features/sync/data/sync_operation.dart`).
///
/// [retrying] a été ajouté au Module 6 : distinct de [failed], qui est
/// désormais réservé à l'échec définitif (nombre maximal de tentatives
/// atteint) — voir `SyncService` pour la logique de décision entre les
/// deux.
enum SyncEventStatus { pending, inProgress, synced, failed, retrying }

/// Priorité d'une opération dans la file de synchronisation (Directive
/// Module 6, "chaque opération possède... une priorité").
///
/// Les opérations de priorité haute sont transmises avant les autres au
/// sein d'une même exécution de synchronisation — voir `SyncService`.
enum SyncPriority { basse, normale, haute }

/// Table Drift représentant la file d'attente de synchronisation
/// (Offline First — voir Architecture technique, section 4).
///
/// Posée comme pure structure au Module 1 ; complétée au Module 6 avec
/// les champs nécessaires au moteur réel (priorité, horodatage de la
/// dernière tentative, dernière erreur) sans jamais renommer ni retirer
/// les colonnes déjà utilisées par les modules 3, 4 et 5 — leurs appels à
/// `SyncEventSink.enqueue()` restent valides à l'identique.
class SyncEventsTable extends Table {
  /// Identifiant unique généré côté client (UUID), pour éviter tout
  /// doublon en cas de nouvelle tentative d'envoi.
  TextColumn get id => text()();

  /// Type d'événement métier (ex. "tournee_telechargee",
  /// "demande_coursier_creee").
  TextColumn get eventType => text()();

  /// Contenu de l'événement, sérialisé (JSON) — le format exact dépend du
  /// module qui produit l'événement.
  TextColumn get payload => text()();

  /// Ordre chronologique de création, utilisé pour rejouer les événements
  /// dans l'ordre exact où ils ont eu lieu au sein d'une même priorité.
  DateTimeColumn get createdAt => dateTime()();

  TextColumn get status => textEnum<SyncEventStatus>()();

  /// Nombre de tentatives de transmission déjà effectuées.
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// Ajouté au Module 6.
  TextColumn get priority =>
      textEnum<SyncPriority>().withDefault(Constant(SyncPriority.normale.name))();

  /// Ajouté au Module 6 — horodatage de la dernière tentative (réussie ou
  /// non), pour le journal de synchronisation.
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Ajouté au Module 6 — message d'erreur de la dernière tentative
  /// échouée, pour le diagnostic (Directive : "Journal... erreurs").
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
