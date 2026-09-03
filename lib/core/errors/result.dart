import 'package:genesis_picking/core/errors/app_exception.dart';

/// Résultat d'une opération pouvant échouer, sans recourir à `throw` dans
/// le flux normal du code métier.
///
/// Utilisé par toutes les couches `data` et `domain` des futurs modules
/// (authentification, téléchargement de tournée, synchronisation...) pour
/// que chaque appelant soit obligé de traiter explicitement le cas
/// d'échec, plutôt que de laisser une exception remonter silencieusement.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(AppException exception) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Transforme la valeur en cas de succès, propage l'échec inchangé.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(value: final value) => Result.success(transform(value)),
      Failure<T>(exception: final exception) => Result.failure(exception),
    };
  }

  /// Point d'entrée unique pour consommer un [Result] sans jamais oublier
  /// le cas d'erreur.
  R when<R>({
    required R Function(T value) success,
    required R Function(AppException exception) failure,
  }) {
    return switch (this) {
      Success<T>(value: final value) => success(value),
      Failure<T>(exception: final exception) => failure(exception),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.exception);
  final AppException exception;
}
