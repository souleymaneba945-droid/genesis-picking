import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/password_hasher.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';

/// Implémentation en mémoire de [UserRepository], utilisée uniquement par
/// les tests unitaires — permet de tester [AuthService] sans dépendre de
/// Drift ni d'une base de données réelle.
class FakeUserRepository implements UserRepository {
  final Map<String, UserAccount> _accounts = {};
  final Map<String, ({String hash, String sel})> _credentials = {};

  /// Identifiants pour lesquels [upsertFromRemote] doit lever une
  /// exception — simule le cas réel d'un doublon de compte local
  /// (contrainte d'unicité SQLite) sans dépendre de Drift.
  final Set<String> echecUpsertPour = {};

  @override
  Future<UserAccount?> findByIdentifiant(String identifiant) async {
    return _accounts[identifiant];
  }

  @override
  Future<({String hash, String sel})?> credentialsFor(
      String identifiant) async {
    return _credentials[identifiant];
  }

  @override
  Future<List<UserAccount>> listAll() async => _accounts.values.toList();

  @override
  Future<Result<UserAccount>> create({
    required String identifiant,
    required String nomAffichage,
    required UserRole role,
    required String motDePasse,
  }) async {
    if (_accounts.containsKey(identifiant)) {
      return const Result.failure(
        ValidationException('Cet identifiant est déjà utilisé.'),
      );
    }
    final salt = PasswordHasher.generateSalt();
    final account = UserAccount(
      id: identifiant,
      identifiant: identifiant,
      nomAffichage: nomAffichage,
      role: role,
      actif: true,
      creeLe: DateTime.now(),
    );
    _accounts[identifiant] = account;
    _credentials[identifiant] = (
      hash: PasswordHasher.hash(password: motDePasse, salt: salt),
      sel: salt,
    );
    return Result.success(account);
  }

  @override
  Future<Result<void>> setActive({
    required String userId,
    required bool actif,
  }) async {
    final account = _accounts[userId];
    if (account == null) {
      return const Result.failure(ValidationException('Compte introuvable.'));
    }
    _accounts[userId] = account.copyWith(actif: actif);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> resetPassword({
    required String userId,
    required String nouveauMotDePasse,
  }) async {
    if (!_accounts.containsKey(userId)) {
      return const Result.failure(ValidationException('Compte introuvable.'));
    }
    final salt = PasswordHasher.generateSalt();
    _credentials[userId] = (
      hash: PasswordHasher.hash(password: nouveauMotDePasse, salt: salt),
      sel: salt,
    );
    return const Result.success(null);
  }

  @override
  Future<bool> isEmpty() async => _accounts.isEmpty;

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
    if (echecUpsertPour.contains(identifiant)) {
      throw StateError('Doublon local simulé pour "$identifiant"');
    }
    _accounts[identifiant] = UserAccount(
      id: id,
      identifiant: identifiant,
      nomAffichage: nomAffichage,
      role: role,
      actif: actif,
      creeLe: creeLe,
    );
    _credentials[identifiant] = (hash: motDePasseHash, sel: motDePasseSel);
  }
}
