import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';

/// Résout le problème de démarrage à froid : sans aucun compte existant,
/// personne ne peut se connecter pour en créer un premier.
///
/// Si aucun compte n'existe encore dans la base locale, un compte
/// Administrateur par défaut est créé, avec des identifiants qui doivent
/// être changés immédiatement (voir [defaultIdentifiant] /
/// [defaultMotDePasse] — affichés uniquement dans les logs de premier
/// démarrage, jamais codés en dur dans un écran visible).
///
/// IMPORTANT — [seedIfNeeded] doit TOUJOURS être appelé après
/// `UserPullSync.pullAll()`, jamais avant (voir `SplashScreen._bootstrap`) :
/// [seedIfNeeded] crée le compte ET le pousse immédiatement vers Firestore
/// (voir `SyncingUserRepository.create`), avant même de savoir qu'un vrai
/// admin existe peut-être déjà sur le serveur. Appelé avant le pull, ça
/// crée un nouveau doublon "admin" à CHAQUE nouvelle installation — 13
/// comptes distincts accumulés ainsi en 4 jours avant que ce bug ne soit
/// identifié et corrigé (04/09/2026).
class DatabaseSeeder {
  DatabaseSeeder(this._userRepository);

  final UserRepository _userRepository;

  static const String defaultIdentifiant = 'admin';
  static const String defaultMotDePasse = 'PremiereConnexion-9K2m!Qz';

  Future<void> seedIfNeeded() async {
    final isEmpty = await _userRepository.isEmpty();
    AppLogger.event('DEBUG seed: isEmpty=$isEmpty', tag: 'DatabaseSeeder');
    if (!isEmpty) return;

    await _userRepository.create(
      identifiant: defaultIdentifiant,
      nomAffichage: 'Administrateur',
      role: UserRole.administrateur,
      motDePasse: defaultMotDePasse,
    );

    AppLogger.warning(
      'Aucun compte trouvé : compte administrateur par défaut créé '
      '(identifiant "$defaultIdentifiant"). '
      'Changez ce mot de passe immédiatement depuis Gestion des comptes.',
      tag: 'DatabaseSeeder',
    );
  }
}
