import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';

/// Progression d'une tournée — exactement les trois informations
/// demandées par la Directive : produits traités, total, pourcentage.
/// Aucune autre donnée n'est calculée ici.
class PickingProgress {
  const PickingProgress({required this.traites, required this.total});

  final int traites;
  final int total;

  double get pourcentage => total == 0 ? 0 : traites / total;
}

/// État complet d'une session de picking, tel que présenté à l'écran.
///
/// [produitCourant] est `null` uniquement lorsque tous les produits ont
/// un état final — dans ce cas, l'écran de picking laisse place à l'écran
/// de fin de tournée (voir `picking_screen.dart`).
class PickingSession {
  const PickingSession({
    required this.tour,
    required this.produits,
    required this.produitCourant,
    required this.progression,
  });

  final Tour tour;
  final List<PickingProduct> produits;
  final PickingProduct? produitCourant;
  final PickingProgress progression;

  bool get estTerminee => produitCourant == null;
}
