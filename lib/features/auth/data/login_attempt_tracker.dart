import 'package:genesis_picking/core/constants/app_constants.dart';

/// Suit les tentatives de connexion échouées par identifiant, pour
/// appliquer la règle du Processus 1 : "3 tentatives échouées →
/// verrouillage 60 secondes".
///
/// Suivi en mémoire, propre à la session de l'application (redémarrer
/// l'application réinitialise le compteur). C'est un choix assumé pour la
/// V1 : l'objectif de cette règle est de ralentir une tentative
/// automatisée en direct, pas de sanctionner durablement un compte — une
/// sanction durable relèverait d'une désactivation de compte par
/// l'Administrateur (voir `user_repository.dart`), pas de ce mécanisme.
class LoginAttemptTracker {
  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockedUntil = {};

  /// Retourne la durée restante de verrouillage, ou `null` si l'identifiant
  /// n'est pas verrouillé.
  Duration? lockoutRemaining(String identifiant) {
    final until = _lockedUntil[identifiant];
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      _lockedUntil.remove(identifiant);
      _failedAttempts.remove(identifiant);
      return null;
    }
    return remaining;
  }

  /// À appeler après un échec de vérification du mot de passe. Déclenche
  /// le verrouillage si le seuil est atteint.
  void recordFailure(String identifiant) {
    final count = (_failedAttempts[identifiant] ?? 0) + 1;
    _failedAttempts[identifiant] = count;
    if (count >= AppConstants.maxLoginAttempts) {
      _lockedUntil[identifiant] = DateTime.now().add(
        AppConstants.loginLockoutDuration,
      );
    }
  }

  /// À appeler après une connexion réussie, pour repartir sur un compteur
  /// propre.
  void reset(String identifiant) {
    _failedAttempts.remove(identifiant);
    _lockedUntil.remove(identifiant);
  }
}
