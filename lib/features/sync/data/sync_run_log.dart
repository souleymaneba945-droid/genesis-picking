/// Une exécution de synchronisation, telle qu'enregistrée par le journal
/// (Directive Module 6, "Journal") : début, fin, durée, nombre
/// d'éléments, erreurs.
class SyncRunLog {
  const SyncRunLog({
    required this.id,
    required this.startedAt,
    required this.itemsProcessed,
    required this.itemsSucceeded,
    required this.itemsFailed,
    this.finishedAt,
    this.errorSummary,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int itemsProcessed;
  final int itemsSucceeded;
  final int itemsFailed;
  final String? errorSummary;

  Duration? get duree =>
      finishedAt == null ? null : finishedAt!.difference(startedAt);

  bool get estEnCours => finishedAt == null;
}
