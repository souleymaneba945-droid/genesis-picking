import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:genesis_picking/core/constants/app_constants.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/session/user_session.dart';

/// Gère le cycle de vie de la session utilisateur : ouverture, persistance
/// locale, restauration au démarrage, fermeture.
///
/// Conforme au Processus 1 (Connexion) : "la session est conservée pour
/// éviter une nouvelle saisie à chaque utilisation" et reste valide même
/// sans réseau, tant qu'elle a été ouverte au moins une fois avec succès.
///
/// Le Module 2 sera responsable de la vérification des identifiants
/// elle-même (appel réseau/local d'authentification) ; ce gestionnaire ne
/// fait que persister et restituer une session déjà établie.
class SessionManager {
  SessionManager({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  UserSession? _currentSession;

  UserSession? get currentSession => _currentSession;
  bool get isAuthenticated => _currentSession != null;

  /// Ouvre et persiste une nouvelle session. Appelé par le Module 2 une
  /// fois les identifiants validés.
  Future<Result<UserSession>> openSession(UserSession session) async {
    try {
      await _secureStorage.write(
        key: AppConstants.secureStorageKeyToken,
        value: session.token,
      );
      await _secureStorage.write(
        key: AppConstants.secureStorageKeyRole,
        value: session.role.storageKey,
      );
      await _secureStorage.write(
        key: AppConstants.secureStorageKeyUserId,
        value: session.userId,
      );
      _currentSession = session;
      AppLogger.event(
        'Session ouverte pour ${session.userId} (${session.role.storageKey})',
        tag: 'SessionManager',
      );
      return Result.success(session);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Échec d\'ouverture de session',
        tag: 'SessionManager',
        error: error,
        stackTrace: stackTrace,
      );
      return Result.failure(
        StorageException('Impossible d\'enregistrer la session', cause: error),
      );
    }
  }

  /// Restaure une session existante depuis le stockage sécurisé, sans
  /// nécessiter de réseau (Processus 1, cas "session locale valide").
  ///
  /// Ne restaure que l'identité et le rôle : le nom d'affichage complet
  /// sera rechargé par le Module 2 dès qu'un réseau est disponible.
  Future<UserSession?> restoreSession() async {
    try {
      final token = await _secureStorage.read(
        key: AppConstants.secureStorageKeyToken,
      );
      final roleKey = await _secureStorage.read(
        key: AppConstants.secureStorageKeyRole,
      );
      final userId = await _secureStorage.read(
        key: AppConstants.secureStorageKeyUserId,
      );

      if (token == null || roleKey == null || userId == null) {
        return null;
      }

      final session = UserSession(
        userId: userId,
        displayName: userId, // Complété par le Module 2 dès reconnexion.
        role: UserRoleStorage.fromStorageKey(roleKey),
        token: token,
      );
      _currentSession = session;
      AppLogger.info('Session restaurée pour $userId', tag: 'SessionManager');
      return session;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Échec de restauration de session',
        tag: 'SessionManager',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> closeSession() async {
    final userId = _currentSession?.userId;
    await _secureStorage.deleteAll();
    _currentSession = null;
    AppLogger.event('Session fermée pour $userId', tag: 'SessionManager');
  }
}
