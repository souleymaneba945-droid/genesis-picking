/// Un coursier tel que présenté à l'écran "Choix du coursier".
///
/// Exactement les deux informations demandées par la Directive : nom,
/// nombre de demandes en attente. Rien d'autre.
class CourierSummary {
  const CourierSummary({
    required this.id,
    required this.nom,
    required this.demandesEnAttente,
  });

  final String id;
  final String nom;
  final int demandesEnAttente;
}
