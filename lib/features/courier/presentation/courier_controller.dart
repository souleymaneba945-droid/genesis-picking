import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request_summary.dart';

/// Contrôleur de l'écran "Mes demandes" du coursier connecté.
///
/// Ne contient aucune logique métier : délègue entièrement à
/// [CourierService] (Directive : "Le coursier voit uniquement ses
/// demandes, leur priorité, leur état.") — la liste renvoyée par le
/// service est déjà triée par priorité (la plus ancienne demande en
/// premier), et chaque demande est accompagnée du nom du préparateur qui
/// l'a envoyée ainsi que du produit concerné (nom + photo), pour
/// permettre le regroupement par préparateur ET l'affichage de la photo
/// à l'écran.
class CourierController extends AsyncNotifier<List<CourierRequestSummary>> {
  @override
  Future<List<CourierRequestSummary>> build() async {
    final coursierId = ref.watch(sessionProvider)!.userId;

    // Réagit automatiquement dès qu'une nouvelle demande arrive côté
    // serveur (voir `courierRequestsWatchProvider` /
    // `CourierService.watchRequestsForCoursier`) — sans ce `listen`,
    // l'écran ne se mettrait à jour qu'à la prochaine ouverture manuelle
    // ou pression sur "Actualiser". Seul le déclenchement compte ici :
    // l'enrichissement (nom du produit, nom du préparateur) reste fait
    // ci-dessous par [listRequestsForCoursierWithPreparateur], jamais par
    // ce flux brut.
    ref.listen(courierRequestsWatchProvider(coursierId), (_, __) {
      ref.invalidateSelf();
    });

    return ref
        .read(courierServiceProvider)
        .listRequestsForCoursierWithPreparateur(coursierId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final courierControllerProvider =
    AsyncNotifierProvider<CourierController, List<CourierRequestSummary>>(
  CourierController.new,
);
