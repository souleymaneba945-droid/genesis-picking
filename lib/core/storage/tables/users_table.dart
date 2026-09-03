import 'package:drift/drift.dart';
import 'package:genesis_picking/core/session/user_role.dart';

/// Table des comptes utilisateurs.
///
/// Ajoutée par le Module 2 (Authentification et gestion des utilisateurs).
/// Les comptes sont créés et gérés localement par l'Administrateur en V1 ;
/// leur synchronisation avec un éventuel serveur central sera ajoutée par
/// le Module 7, sans changer cette table.
///
/// Le mot de passe n'est jamais stocké en clair : seuls [motDePasseHash] et
/// [motDePasseSel] (sel aléatoire propre à chaque compte) sont conservés —
/// voir `password_hasher.dart`.
class UsersTable extends Table {
  TextColumn get id => text()();

  /// Identifiant de connexion, unique (voir Processus 1).
  TextColumn get identifiant => text().unique()();

  TextColumn get nomAffichage => text()();

  TextColumn get role => textEnum<UserRole>()();

  TextColumn get motDePasseHash => text()();
  TextColumn get motDePasseSel => text()();

  /// Un compte désactivé ne peut plus se connecter (Cahier des charges,
  /// section 1 : "désactiver un compte"), sans être supprimé — ses actions
  /// passées restent tracées.
  BoolColumn get actif => boolean().withDefault(const Constant(true))();

  DateTimeColumn get creeLe => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
