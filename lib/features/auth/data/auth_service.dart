import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/session/user_session.dart';
import 'package:genesis_picking/features/auth/data/login_attempt_tracker.dart';
import 'package:genesis_picking/features/auth/data/password_hasher.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';
import 'package:uuid/uuid.dart';

/// Service d'authentification — implémente exactement le Processus 1
/// (Connexion) de la Spécification Fonctionnelle et du document
/// "Processus métier V1" :
/// - vérifie l'identifiant et le mot de passe,
/// - détermine le rôle,
/// - applique le verrouillage après 3 tentatives échouées,
/// - refuse la connexion pour un compte désactivé.
///
/// Ne persiste jamais la session lui-même : il retourne un [UserSession]
/// prêt à être transmis à `SessionNotifier.open()` (Module 1), qui se
/// charge de la persistance sécurisée. Cette séparation évite que ce
/// service ait à connaître les détails du stockage de session.
class AuthService {
  AuthService({
    required UserRepository userRepository,
    LoginAttemptTracker? attemptTracker,
    Uuid? uuid,
  })  : _userRepository = userRepository,
        _attemptTracker = attemptTracker ?? LoginAttemptTracker(),
        _uuid = uuid ?? const Uuid();

  final UserRepository _userRepository;
  final LoginAttemptTracker _attemptTracker;
  final Uuid _uuid;

  Future<Result<UserSession>> login({
    required String identifiant,
    required String motDePasse,
  }) async {
    final remaining = _attemptTracker.lockoutRemaining(identifiant);
    if (remaining != null) {
      AppLogger.warning(
        'Connexion refusée (verrouillage actif) : $identifiant',
        tag: 'AuthService',
      );
      return Result.failure(
        SessionException(
          'Trop de tentatives. Réessayez dans ${remaining.inSeconds} secondes.',
        ),
      );
    }

    final account = await _userRepository.findByIdentifiant(identifiant);
    final credentials = await _userRepository.credentialsFor(identifiant);

    if (account == null || credentials == null) {
      _attemptTracker.recordFailure(identifiant);
      AppLogger.event(
        'Échec de connexion (identifiant inconnu) : $identifiant',
        tag: 'AuthService',
      );
      return const Result.failure(
        SessionException('Identifiant ou mot de passe incorrect.'),
      );
    }

    if (!account.actif) {
      // Un compte désactivé n'est pas comptabilisé comme une tentative
      // échouée : ce n'est pas une erreur de saisie de l'utilisateur.
      AppLogger.event(
        'Connexion refusée (compte désactivé) : $identifiant',
        tag: 'AuthService',
      );
      return const Result.failure(
        SessionException(
          'Ce compte n\'est plus actif. Contactez votre administrateur.',
        ),
      );
    }

    final isValid = PasswordHasher.verify(
      password: motDePasse,
      salt: credentials.sel,
      expectedHash: credentials.hash,
    );

    if (!isValid) {
      _attemptTracker.recordFailure(identifiant);
      AppLogger.event(
        'Échec de connexion (mot de passe incorrect) : $identifiant',
        tag: 'AuthService',
      );
      return const Result.failure(
        SessionException('Identifiant ou mot de passe incorrect.'),
      );
    }

    _attemptTracker.reset(identifiant);
    AppLogger.event('Connexion réussie : $identifiant', tag: 'AuthService');

    // Migration transparente du hachage (voir la docstring de
    // `PasswordHasher`) : ce compte vérifie encore avec l'ancien format
    // (SHA-256 simple) — on connaît le mot de passe en clair À CET
    // INSTANT PRÉCIS (on vient de le vérifier), c'est la seule occasion
    // de le re-hacher sans rien demander à l'utilisateur. Best-effort :
    // un échec ici ne doit jamais faire échouer une connexion par
    // ailleurs réussie, seulement retenter à la prochaine connexion.
    if (PasswordHasher.necessiteRehachage(credentials.hash)) {
      try {
        await _userRepository.resetPassword(
          userId: account.id,
          nouveauMotDePasse: motDePasse,
        );
        AppLogger.event(
          'Hachage renforcé pour le compte $identifiant',
          tag: 'AuthService',
        );
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Renforcement du hachage différé pour $identifiant (retentera '
          'à la prochaine connexion)',
          tag: 'AuthService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return Result.success(
      UserSession(
        userId: account.id,
        displayName: account.nomAffichage,
        role: account.role,
        token: _uuid.v4(),
      ),
    );
  }
}
