/// États métier d'une tournée.
///
/// Reprend exactement les 4 états d'avancement définis dans le PRD
/// (chapitre 4.1) : Disponible → Téléchargée → En cours → Terminée.
/// Aucun autre état ne doit être ajouté sans repasser par le PRD.
///
/// IMPORTANT : la transition vers [terminee] ne doit être déclenchée que
/// lorsque tous les produits de la tournée ont un état final — cette
/// vérification appartient au Module 4 (Picking), pas à ce module. Le
/// Module 3 fournit uniquement le mécanisme de transition
/// (`TourService.completeTour`), pas la décision de l'appeler.
enum TourStatus { disponible, telechargee, enCours, terminee }

/// État de synchronisation d'une tournée — axe transverse et indépendant
/// de [TourStatus] (une tournée "En cours" peut être synchronisée ou non,
/// tout comme une tournée "Terminée").
///
/// Ce sont les deux derniers états cités dans le PRD ("Synchronisée",
/// "En attente de synchronisation"), modélisés séparément de
/// [TourStatus] conformément à la distinction déjà posée dans le PRD,
/// chapitre 4.1 : "état transverse... indépendant de l'état métier".
enum TourSyncState { enAttenteSynchronisation, synchronisee }
