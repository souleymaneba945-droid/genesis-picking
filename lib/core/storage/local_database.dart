import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:genesis_picking/core/constants/app_constants.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/storage/local_storage_service.dart';
import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/storage/tables/activity_log_table.dart';
import 'package:genesis_picking/core/storage/tables/app_metadata_table.dart';
import 'package:genesis_picking/core/storage/tables/users_table.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:genesis_picking/core/sync/sync_event.dart';
import 'package:genesis_picking/features/import/data/import_format.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/courier/data/tables/courier_requests_table.dart';
import 'package:genesis_picking/features/import/data/tables/import_history_table.dart';
import 'package:genesis_picking/features/picking/data/tables/picking_product_statuses_table.dart';
import 'package:genesis_picking/features/sync/data/tables/sync_run_logs_table.dart';
import 'package:genesis_picking/features/tours/data/tables/tour_product_lines_table.dart';
import 'package:genesis_picking/features/tours/data/tables/tours_table.dart';

part 'local_database.g.dart';

/// Base de données locale unique de l'application (principe Offline First).
///
/// Toutes les tables métier des futurs modules (tournées, produits,
/// demandes coursier — Modules 3, 4, 5) seront ajoutées à la liste
/// [tables] ci-dessous, chacune définie dans son propre fichier sous
/// `core/storage/tables/`. Ce fichier ne contient volontairement, en
/// Module 1, que les tables transverses : métadonnées et file de
/// synchronisation.
///
/// NOTE DE GÉNÉRATION : ce fichier utilise `part 'local_database.g.dart'`,
/// généré par `drift_dev` via :
///   dart run build_runner build --delete-conflicting-outputs
/// Le fichier généré n'est volontairement pas commité tel quel dans ce
/// livrable (voir README, section "Tests réalisés").
@DriftDatabase(
  tables: [
    AppMetadataTable,
    SyncEventsTable,
    UsersTable,
    ToursTable,
    TourProductLinesTable,
    PickingProductStatusesTable,
    CourierRequestsTable,
    SyncRunLogsTable,
    ImportHistoryTable,
    ActivityLogTable,
  ],
)
class LocalDatabase extends _$LocalDatabase implements LocalStorageService {
  LocalDatabase() : super(_openConnection());

  bool _isOpen = false;

  // Module 1 : schéma initial (AppMetadataTable, SyncEventsTable).
  // Module 2 : ajout de UsersTable → schéma 2.
  // Module 3 : ajout de ToursTable et TourProductLinesTable → schéma 3.
  // Module 4 : ajout de PickingProductStatusesTable → schéma 4.
  // Module 5 : ajout de CourierRequestsTable → schéma 5.
  // Module 6 : colonnes priority/lastAttemptAt/lastError + SyncRunLogsTable → schéma 6.
  // Moteur d'import : ajout de ImportHistoryTable → schéma 7.
  // Historique d'activité : ajout de ActivityLogTable → schéma 8, avec
  // migration associée ci-dessous (aucune perte de données locales).
  // Instantané produit (nom/description/photo) sur CourierRequestsTable →
  // schéma 9 : corrige l'absence d'image/description sur l'appareil d'un
  // coursier qui n'a jamais téléchargé la tournée (voir `CourierService`).
  // Colonnes dateDebut/dateFin sur ToursTable → schéma 10 : mesure de la
  // durée réelle de picking (voir `Tour.dureeEcoulee`).
  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(usersTable);
          }
          if (from < 3) {
            await migrator.createTable(toursTable);
            await migrator.createTable(tourProductLinesTable);
          }
          if (from < 4) {
            await migrator.createTable(pickingProductStatusesTable);
          }
          if (from < 5) {
            await migrator.createTable(courierRequestsTable);
          }
          if (from < 6) {
            await migrator.addColumn(syncEventsTable, syncEventsTable.priority);
            await migrator.addColumn(
              syncEventsTable,
              syncEventsTable.lastAttemptAt,
            );
            await migrator.addColumn(
                syncEventsTable, syncEventsTable.lastError);
            await migrator.createTable(syncRunLogsTable);
          }
          if (from < 7) {
            await migrator.createTable(importHistoryTable);
          }
          if (from < 8) {
            await migrator.createTable(activityLogTable);
          }
          if (from < 9) {
            await migrator.addColumn(
              courierRequestsTable,
              courierRequestsTable.produitNom,
            );
            await migrator.addColumn(
              courierRequestsTable,
              courierRequestsTable.produitDescription,
            );
            await migrator.addColumn(
              courierRequestsTable,
              courierRequestsTable.produitImageUrl,
            );
          }
          if (from < 10) {
            await migrator.addColumn(toursTable, toursTable.dateDebut);
            await migrator.addColumn(toursTable, toursTable.dateFin);
          }
        },
      );

  @override
  Future<void> open() async {
    // Drift ouvre la connexion paresseusement au premier accès ; on force
    // ici une requête triviale pour garantir que la base est prête avant
    // que le reste de l'application ne démarre.
    await customSelect('SELECT 1').getSingleOrNull();
    _isOpen = true;
    AppLogger.info('Base de données locale ouverte', tag: 'LocalDatabase');
  }

  @override
  Future<void> close() async {
    await super.close();
    _isOpen = false;
  }

  @override
  bool get isOpen => _isOpen;
}

/// Connexion multiplateforme unique : SQLite natif sur Android/iOS/
/// desktop, SQLite compilé en WebAssembly (stocké via IndexedDB) sur le
/// Web — un seul code, `drift_flutter` choisit automatiquement le bon
/// mécanisme selon la plateforme d'exécution.
QueryExecutor _openConnection() {
  return driftDatabase(
    name: AppConstants.databaseFileName,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
