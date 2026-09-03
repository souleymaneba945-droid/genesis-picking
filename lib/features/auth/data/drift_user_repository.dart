import 'package:drift/drift.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/storage/local_database.dart';
import 'package:genesis_picking/features/auth/data/password_hasher.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';
import 'package:uuid/uuid.dart';

/// Implémentation Drift de [UserRepository].
class DriftUserRepository implements UserRepository {
  DriftUserRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final Uuid _uuid;

  @override
  Future<UserAccount?> findByIdentifiant(String identifiant) async {
    final row = await (_database.select(
      _database.usersTable,
    )..where((tbl) => tbl.identifiant.equals(identifiant)))
        .getSingleOrNull();
    return row == null ? null : _toAccount(row);
  }

  @override
  Future<({String hash, String sel})?> credentialsFor(
      String identifiant) async {
    final row = await (_database.select(
      _database.usersTable,
    )..where((tbl) => tbl.identifiant.equals(identifiant)))
        .getSingleOrNull();
    if (row == null) return null;
    return (hash: row.motDePasseHash, sel: row.motDePasseSel);
  }

  @override
  Future<List<UserAccount>> listAll() async {
    final rows = await _database.select(_database.usersTable).get();
    return rows.map(_toAccount).toList();
  }

  @override
  Future<Result<UserAccount>> create({
    required String identifiant,
    required String nomAffichage,
    required UserRole role,
    required String motDePasse,
  }) async {
    final existing = await findByIdentifiant(identifiant);
    if (existing != null) {
      return const Result.failure(
        ValidationException('Cet identifiant est déjà utilisé.'),
      );
    }

    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(password: motDePasse, salt: salt);
    final id = _uuid.v4();
    final creeLe = DateTime.now();

    await _database.into(_database.usersTable).insert(
          UsersTableCompanion.insert(
            id: id,
            identifiant: identifiant,
            nomAffichage: nomAffichage,
            role: role,
            motDePasseHash: hash,
            motDePasseSel: salt,
            creeLe: creeLe,
          ),
        );

    AppLogger.event('Compte créé : $identifiant ($role)',
        tag: 'UserRepository');

    return Result.success(
      UserAccount(
        id: id,
        identifiant: identifiant,
        nomAffichage: nomAffichage,
        role: role,
        actif: true,
        creeLe: creeLe,
      ),
    );
  }

  @override
  Future<Result<void>> setActive({
    required String userId,
    required bool actif,
  }) async {
    final updated = await (_database.update(
      _database.usersTable,
    )..where((tbl) => tbl.id.equals(userId)))
        .write(
      UsersTableCompanion(actif: Value(actif)),
    );

    if (updated == 0) {
      return const Result.failure(
        ValidationException('Compte introuvable.'),
      );
    }

    AppLogger.event(
      'Compte ${actif ? 'réactivé' : 'désactivé'} : $userId',
      tag: 'UserRepository',
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> resetPassword({
    required String userId,
    required String nouveauMotDePasse,
  }) async {
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(password: nouveauMotDePasse, salt: salt);

    final updated = await (_database.update(
      _database.usersTable,
    )..where((tbl) => tbl.id.equals(userId)))
        .write(
      UsersTableCompanion(
          motDePasseHash: Value(hash), motDePasseSel: Value(salt)),
    );

    if (updated == 0) {
      return const Result.failure(
        ValidationException('Compte introuvable.'),
      );
    }

    AppLogger.event('Mot de passe réinitialisé : $userId',
        tag: 'UserRepository');
    return const Result.success(null);
  }

  @override
  Future<bool> isEmpty() async {
    final row = await _database.select(_database.usersTable).get();
    return row.isEmpty;
  }

  @override
  Future<void> upsertFromRemote({
    required String id,
    required String identifiant,
    required String nomAffichage,
    required UserRole role,
    required bool actif,
    required String motDePasseHash,
    required String motDePasseSel,
    required DateTime creeLe,
  }) async {
    // `insertOnConflictUpdate` ne résout les conflits que sur la clé
    // primaire (id) — si CET appareil possède déjà, localement, un compte
    // portant le même identifiant mais un id DIFFÉRENT (typiquement : un
    // compte créé localement sur cet appareil avant que la synchronisation
    // réelle n'existe, en doublon avec un compte de même nom créé depuis
    // sur un autre appareil), l'insertion ci-dessous violerait la
    // contrainte d'unicité sur `identifiant` et ferait échouer TOUTE la
    // récupération des comptes en cours (voir `UserPullSync.pullAll`).
    // Le serveur central fait foi désormais : on efface ce doublon
    // local avant d'accueillir la version du serveur sous son propre id.
    final doublonLocal = await findByIdentifiant(identifiant);
    if (doublonLocal != null && doublonLocal.id != id) {
      AppLogger.warning(
        'Compte local en doublon pour "$identifiant" (id local '
        '${doublonLocal.id} ≠ id serveur $id) — remplacé par la version '
        'du serveur, seule source commune à tous les appareils',
        tag: 'DriftUserRepository',
      );
      await (_database.delete(
        _database.usersTable,
      )..where((tbl) => tbl.id.equals(doublonLocal.id)))
          .go();
    }

    await _database.into(_database.usersTable).insertOnConflictUpdate(
          UsersTableCompanion.insert(
            id: id,
            identifiant: identifiant,
            nomAffichage: nomAffichage,
            role: role,
            motDePasseHash: motDePasseHash,
            motDePasseSel: motDePasseSel,
            creeLe: creeLe,
            actif: Value(actif),
          ),
        );
  }

  UserAccount _toAccount(UsersTableData row) {
    return UserAccount(
      id: row.id,
      identifiant: row.identifiant,
      nomAffichage: row.nomAffichage,
      role: row.role,
      actif: row.actif,
      creeLe: row.creeLe,
    );
  }
}
