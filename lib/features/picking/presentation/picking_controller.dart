import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';
import 'package:genesis_picking/features/picking/domain/picking_service.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';
import 'package:genesis_picking/features/picking/picking_providers.dart';

/// Contrôleur du moteur de picking pour UNE tournée (`arg` = `tourId`).
///
/// Ne contient aucune logique métier elle-même : chaque méthode délègue
/// immédiatement à [PickingService] et se contente de refléter le
/// résultat dans l'état observé par l'écran (Directive : "Le changement
/// doit être instantané").
class PickingController extends FamilyAsyncNotifier<PickingSession, String> {
  @override
  Future<PickingSession> build(String tourId) async {
    final result = await _service.openSession(tourId);
    return result.when(success: (session) => session, failure: (e) => throw e);
  }

  PickingService get _service => ref.read(pickingServiceProvider);

  /// Valide le produit courant (Directive, "Validation").
  ///
  /// [quantiteCollectee] est la quantité réellement trouvée : si elle
  /// égale la quantité demandée, l'état devient [ProductState.collecte] ;
  /// sinon [ProductState.partiellementCollecte]. Après validation, la
  /// session est automatiquement repositionnée sur le produit suivant —
  /// aucun retour manuel, aucune étape intermédiaire.
  Future<void> validerProduitCourant({required int quantiteCollectee}) async {
    final session = state.valueOrNull;
    final produit = session?.produitCourant;
    if (produit == null) return;

    final etat = quantiteCollectee >= produit.quantiteDemandee
        ? ProductState.collecte
        : ProductState.partiellementCollecte;

    final result = await _service.validateCurrentProduct(
      tourId: arg,
      productLineId: produit.id,
      etat: etat,
      quantiteCollectee: quantiteCollectee,
    );

    result.when(
      success: (newSession) => state = AsyncValue.data(newSession),
      failure: (exception) =>
          state = AsyncValue.error(exception, StackTrace.current),
    );
  }

  /// Point d'entrée "Produit introuvable" (Directive) : passe le produit
  /// courant à l'état [ProductState.introuvable] et avance au produit
  /// suivant. Le choix du coursier arrive au Module 5.
  Future<void> signalerIntrouvable() async {
    final session = state.valueOrNull;
    final produit = session?.produitCourant;
    if (produit == null) return;

    final result = await _service.markCurrentProductIntrouvable(
      tourId: arg,
      productLineId: produit.id,
    );

    result.when(
      success: (newSession) => state = AsyncValue.data(newSession),
      failure: (exception) =>
          state = AsyncValue.error(exception, StackTrace.current),
    );
  }

  /// Ajouté pour le mode liste complète (validation ligne par ligne,
  /// dans n'importe quel ordre) : identique à [validerProduitCourant]
  /// mais prend le produit explicitement plutôt que de dépendre du
  /// "produit courant" — nécessaire car toutes les lignes sont visibles
  /// et validables en parallèle, pas seulement la première non traitée.
  Future<void> validerProduit(
    String productLineId, {
    required int quantiteCollectee,
  }) async {
    final session = state.valueOrNull;
    if (session == null) return;
    final produit = session.produits.where((p) => p.id == productLineId);
    if (produit.isEmpty) return;

    final etat = quantiteCollectee >= produit.first.quantiteDemandee
        ? ProductState.collecte
        : ProductState.partiellementCollecte;

    final result = await _service.validateCurrentProduct(
      tourId: arg,
      productLineId: productLineId,
      etat: etat,
      quantiteCollectee: quantiteCollectee,
    );

    result.when(
      success: (newSession) => state = AsyncValue.data(newSession),
      failure: (exception) =>
          state = AsyncValue.error(exception, StackTrace.current),
    );
  }

  /// Marque un produit "Introuvable" explicitement par son id (mode liste
  /// complète — même principe que [validerProduit] par rapport à
  /// [validerProduitCourant]) : un simple constat, sans déclencher aucune
  /// suite (le choix d'un coursier reste une action séparée et volontaire,
  /// voir le 3ᵉ bouton de chaque ligne — [marquerEnvoyeAuCoursier]).
  Future<void> marquerIntrouvable(String productLineId) async {
    final result = await _service.markCurrentProductIntrouvable(
      tourId: arg,
      productLineId: productLineId,
    );

    result.when(
      success: (newSession) => state = AsyncValue.data(newSession),
      failure: (exception) =>
          state = AsyncValue.error(exception, StackTrace.current),
    );
  }

  /// Ajouté au Module 5 — méthode strictement additive, aucune méthode
  /// existante de ce contrôleur n'est modifiée.
  ///
  /// Fait passer un produit (déjà signalé introuvable, potentiellement
  /// déjà "produit précédent" au sens de la session courante) à l'état
  /// [ProductState.envoyeAuCoursier], une fois qu'une demande coursier a
  /// été créée avec succès (voir `courier_selection_screen.dart`). Prend
  /// [productLineId] explicitement plutôt que de dépendre du produit
  /// courant, car au moment de l'appel la session a déjà avancé au
  /// produit suivant.
  Future<void> marquerEnvoyeAuCoursier(String productLineId) async {
    final result = await _service.validateCurrentProduct(
      tourId: arg,
      productLineId: productLineId,
      etat: ProductState.envoyeAuCoursier,
    );

    result.when(
      success: (newSession) => state = AsyncValue.data(newSession),
      failure: (exception) =>
          state = AsyncValue.error(exception, StackTrace.current),
    );
  }
}

final pickingControllerProvider =
    AsyncNotifierProviderFamily<PickingController, PickingSession, String>(
      PickingController.new,
    );
