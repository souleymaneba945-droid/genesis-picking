import 'package:genesis_picking/core/session/user_role.dart';

/// Un compte tel qu'échangé avec le serveur central — inclut le hash et
/// le sel du mot de passe (jamais le mot de passe en clair), pour que
/// chaque appareil puisse vérifier une connexion 100% localement une
/// fois le compte reçu, sans jamais avoir besoin du réseau pour se
/// connecter (principe Offline First inchangé — seule la PROPAGATION du
/// compte entre appareils a besoin du réseau, pas la connexion elle-même).
class UserRemoteRecord {
  const UserRemoteRecord({
    required this.id,
    required this.identifiant,
    required this.nomAffichage,
    required this.role,
    required this.actif,
    required this.motDePasseHash,
    required this.motDePasseSel,
    required this.creeLe,
  });

  final String id;
  final String identifiant;
  final String nomAffichage;
  final UserRole role;
  final bool actif;
  final String motDePasseHash;
  final String motDePasseSel;
  final DateTime creeLe;
}

/// Point d'échange des comptes utilisateurs avec le serveur central —
/// symétrique de [TourRemoteSource]/[TourRemoteSink] : un `push` après
/// chaque écriture locale (création, activation/désactivation,
/// réinitialisation de mot de passe), un `pullAll` au démarrage pour que
/// chaque appareil connaisse tous les comptes créés ailleurs.
abstract interface class UserRemoteRepository {
  Future<void> push(UserRemoteRecord record);

  Future<List<UserRemoteRecord>> pullAll();
}

/// Implémentation "sans serveur" — utilisée tant que Firebase n'est pas
/// disponible (tests, environnements sans backend).
class NoUserRemoteRepository implements UserRemoteRepository {
  const NoUserRemoteRepository();

  @override
  Future<void> push(UserRemoteRecord record) async {}

  @override
  Future<List<UserRemoteRecord>> pullAll() async => const [];
}
