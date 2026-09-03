/// Racine commune de toutes les erreurs métier ou techniques de
/// l'application.
///
/// Toute erreur qui doit produire un message utilisateur compréhensible
/// (voir Processus 10 — Gestion des erreurs) doit passer par une
/// sous-classe d'[AppException], jamais par une exception brute du SDK.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Message technique (destiné aux logs), jamais affiché tel quel à
  /// l'utilisateur — voir [ErrorHandler.userMessageFor] pour la traduction
  /// en message utilisateur.
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Erreur liée à l'absence ou à l'instabilité du réseau.
///
/// Ne doit jamais être bloquante pour une action locale (voir principe
/// Offline First) — seulement pour les actions qui nécessitent
/// explicitement le réseau (ex. import initial d'une tournée).
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// Erreur de validation d'une donnée saisie par l'utilisateur
/// (ex. quantité invalide — voir Processus 10).
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// Erreur liée au stockage local (lecture/écriture base de données,
/// stockage sécurisé).
final class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// Erreur liée à une session invalide ou expirée (compte désactivé,
/// identifiants incorrects — voir Processus 1).
final class SessionException extends AppException {
  const SessionException(super.message, {super.cause});
}

/// Erreur non anticipée, dernier recours uniquement. Toute nouvelle
/// famille d'erreur récurrente doit obtenir sa propre sous-classe plutôt
/// que d'être routée ici.
final class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause});
}
