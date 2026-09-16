import 'package:genesis_picking/features/courier/data/courier_request.dart';

/// Granularité d'agrégation des statistiques par marque (Modernisation,
/// 16/09/2026, retour explicite de l'utilisateur : "assemblé par marque
/// trouvé ou non trouvé par jour, puis compilé en semaine puis en mois").
enum StatsPeriodGranularity { jour, semaine, mois }

/// Bornes [début inclus, fin EXCLUE) de la période contenant [reference]
/// pour la granularité donnée. La semaine commence le lundi (convention
/// ISO déjà utilisée ailleurs dans le pays/l'équipe), jamais le dimanche.
(DateTime debut, DateTime finExclue) periodBounds(
  DateTime reference,
  StatsPeriodGranularity granularite,
) {
  switch (granularite) {
    case StatsPeriodGranularity.jour:
      final debut = DateTime(reference.year, reference.month, reference.day);
      return (debut, debut.add(const Duration(days: 1)));
    case StatsPeriodGranularity.semaine:
      // `weekday` : 1 = lundi ... 7 = dimanche.
      final jour = DateTime(reference.year, reference.month, reference.day);
      final lundi = jour.subtract(Duration(days: jour.weekday - 1));
      return (lundi, lundi.add(const Duration(days: 7)));
    case StatsPeriodGranularity.mois:
      final debut = DateTime(reference.year, reference.month);
      final finExclue = DateTime(reference.year, reference.month + 1);
      return (debut, finExclue);
  }
}

/// Déplace [reference] d'une période dans le sens de [direction] (`-1` =
/// précédente, `1` = suivante) — jamais une simple addition de jours pour
/// [StatsPeriodGranularity.mois] : un mois n'a pas une durée fixe, on
/// avance directement le numéro du mois (le jour `1` en repli évite tout
/// débordement, ex. 31 janvier + 1 mois).
DateTime shiftPeriod(
  DateTime reference,
  StatsPeriodGranularity granularite,
  int direction,
) {
  return switch (granularite) {
    StatsPeriodGranularity.jour =>
      reference.add(Duration(days: direction)),
    StatsPeriodGranularity.semaine =>
      reference.add(Duration(days: 7 * direction)),
    StatsPeriodGranularity.mois =>
      DateTime(reference.year, reference.month + direction),
  };
}

/// Sous-ensemble de [demandes] dont [CourierRequest.dateCreation] tombe
/// dans `[debut, finExclue)` — la date de CRÉATION, pas de clôture : c'est
/// le moment où le préparateur a signalé le produit introuvable, donc le
/// vrai instant de la "recherche" que l'utilisateur veut suivre.
List<CourierRequest> filterByPeriod(
  List<CourierRequest> demandes,
  DateTime debut,
  DateTime finExclue,
) {
  return demandes
      .where(
        (d) =>
            !d.dateCreation.isBefore(debut) && d.dateCreation.isBefore(finExclue),
      )
      .toList();
}

const _moisFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Libellé humain de la période `[debut, finExclue)` — jamais recalculé
/// deux fois différemment à l'écran, une seule source de vérité.
String periodLabel(
  DateTime debut,
  DateTime finExclue,
  StatsPeriodGranularity granularite,
) {
  String deux(int n) => n.toString().padLeft(2, '0');

  switch (granularite) {
    case StatsPeriodGranularity.jour:
      final aujourdHui = DateTime.now();
      final estAujourdHui = debut.year == aujourdHui.year &&
          debut.month == aujourdHui.month &&
          debut.day == aujourdHui.day;
      final date = '${deux(debut.day)}/${deux(debut.month)}/${debut.year}';
      return estAujourdHui ? 'Aujourd\'hui · $date' : date;
    case StatsPeriodGranularity.semaine:
      final dernierJour = finExclue.subtract(const Duration(days: 1));
      return 'Semaine du ${deux(debut.day)}/${deux(debut.month)} au '
          '${deux(dernierJour.day)}/${deux(dernierJour.month)}/${dernierJour.year}';
    case StatsPeriodGranularity.mois:
      return '${_moisFr[debut.month - 1][0].toUpperCase()}'
          '${_moisFr[debut.month - 1].substring(1)} ${debut.year}';
  }
}
