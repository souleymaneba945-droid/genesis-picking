/// Niveau d'un évènement de l'historique d'activité — détermine
/// uniquement sa couleur/icône à l'écran (succès, avertissement, neutre),
/// jamais une règle métier : c'est le même niveau que celui déjà utilisé
/// pour les rapports d'import (voir `ImportIssueSeverity`), juste un
/// cran supplémentaire pour les évènements neutres (ex. "envoyé au
/// coursier", qui n'est ni un succès ni un problème).
enum ActivityLevel { succes, avertissement, neutre }
