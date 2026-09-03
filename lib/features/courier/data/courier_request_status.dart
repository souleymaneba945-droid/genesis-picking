/// États d'une demande coursier.
///
/// Reprend EXACTEMENT les six états de la Directive Module 5. Aucun autre
/// état ne doit être ajouté sans repasser par cette directive.
enum CourierRequestStatus { creee, enAttente, recue, acceptee, traitee, terminee }

/// Résultat du traitement d'une demande par le coursier — les deux seuls
/// choix autorisés par la Directive ("Aucun autre choix").
enum CourierRequestResult { retrouve, nonRetrouve }
