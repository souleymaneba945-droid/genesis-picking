import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Résultat de la résolution d'un conflit : quelle valeur doit être
/// retenue, et pourquoi (pour le journal).
class ConflictResolution<T> {
  const ConflictResolution({required this.retained, required this.reason});

  final T retained;
  final String reason;
}

/// Stratégie de résolution des conflits de synchronisation.
///
/// Responsabilité UNIQUE : décider quelle valeur retenir entre deux
/// versions concurrentes d'une même donnée. Ne lit ni n'écrit jamais
/// aucune donnée elle-même — c'est `SyncService` qui applique la
/// décision. Couvre explicitement les trois exemples de la Directive.
class ConflictResolver {
  /// Cas général : un état qui progresse dans un flux métier à sens
  /// unique (ex. `TourStatus`, `ProductState`, `CourierRequestStatus`).
  ///
  /// Reprend le principe déjà posé dans le document "Processus métier V1"
  /// (Processus 7) : l'état le plus avancé dans le flux gagne toujours,
  /// qu'il soit local ou distant — un état déjà confirmé n'est jamais
  /// écrasé par un état antérieur reçu en retard.
  ///
  /// [rangDansLeFlux] doit renvoyer un entier croissant avec l'avancement
  /// (ex. 0 pour "À récupérer", 1 pour "Collecté"...).
  ConflictResolution<T> resolveProgressiveState<T>({
    required T local,
    required T remote,
    required int Function(T) rangDansLeFlux,
  }) {
    if (rangDansLeFlux(local) >= rangDansLeFlux(remote)) {
      return ConflictResolution(
        retained: local,
        reason:
            'État local au moins aussi avancé que l\'état distant '
            '(rang ${rangDansLeFlux(local)} ≥ ${rangDansLeFlux(remote)}) — conservé.',
      );
    }
    return ConflictResolution(
      retained: remote,
      reason:
          'État distant plus avancé (rang ${rangDansLeFlux(remote)} > '
          '${rangDansLeFlux(local)}) — retenu.',
    );
  }

  /// Cas général : deux mises à jour concurrentes d'une valeur sans
  /// notion de progression (ex. quantité collectée corrigée). La plus
  /// récente l'emporte.
  ConflictResolution<T> resolveLastWriteWins<T>({
    required T local,
    required DateTime localTimestamp,
    required T remote,
    required DateTime remoteTimestamp,
  }) {
    if (!remoteTimestamp.isAfter(localTimestamp)) {
      return ConflictResolution(
        retained: local,
        reason: 'Écriture locale la plus récente — conservée.',
      );
    }
    return ConflictResolution(
      retained: remote,
      reason: 'Écriture distante plus récente — retenue.',
    );
  }

  /// Exemple de la Directive : "suppression d'une tournée déjà modifiée".
  ///
  /// Règle : le travail de terrain n'est jamais perdu. Si la tournée a
  /// des modifications locales non encore synchronisées, la suppression
  /// distante est refusée et journalisée pour intervention humaine — elle
  /// n'est PAS appliquée automatiquement. Sans modification locale en
  /// attente, la suppression est acceptée sans conflit.
  ConflictResolution<bool> resolveTourDeletionConflict({
    required bool hasUnsyncedLocalChanges,
  }) {
    if (hasUnsyncedLocalChanges) {
      return const ConflictResolution(
        retained: false, // false = ne pas supprimer localement
        reason:
            'Des modifications locales non synchronisées existent : la '
            'suppression distante est ignorée et signalée pour '
            'intervention manuelle (Administration).',
      );
    }
    return const ConflictResolution(
      retained: true, // true = appliquer la suppression
      reason: 'Aucune modification locale en attente : suppression appliquée.',
    );
  }

  /// Exemple de la Directive : "réponse du coursier reçue pendant une
  /// préparation" — deux réponses concurrentes pour la même demande
  /// (cas normalement rare, une demande étant nominative à un seul
  /// coursier, mais possible en cas de rejeu réseau).
  ///
  /// Règle : la première réponse réellement donnée (l'action humaine la
  /// plus ancienne) fait foi ; un produit ne peut pas changer d'issue
  /// après coup une fois une réponse traitée.
  ConflictResolution<CourierRequestResult> resolveCourierResponseConflict({
    required CourierRequestResult first,
    required DateTime firstAt,
    required CourierRequestResult second,
    required DateTime secondAt,
  }) {
    if (!firstAt.isAfter(secondAt)) {
      return ConflictResolution(
        retained: first,
        reason: 'Première réponse reçue (${firstAt.toIso8601String()}) — retenue.',
      );
    }
    return ConflictResolution(
      retained: second,
      reason: 'Réponse reçue en premier (${secondAt.toIso8601String()}) — retenue.',
    );
  }
}
