import 'package:genesis_picking/core/activity/activity_level.dart';
import 'package:genesis_picking/core/activity/activity_log.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/picking_repository.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_repository.dart';
import 'package:genesis_picking/features/tours/domain/tour_service.dart';

/// Service métier du moteur de picking.
///
/// Aucune requête réseau nulle part dans cette classe — conforme à la
/// Directive ("Toutes les données proviennent de la tournée téléchargée.
/// Aucune requête réseau."). Toute la logique repose sur des données déjà
/// stockées localement par le Module 3.
class PickingService {
  PickingService({
    required PickingRepository pickingRepository,
    required TourRepository tourRepository,
    required TourService tourService,
    required ActivityLogSink activityLogSink,
  })  : _pickingRepository = pickingRepository,
        _tourRepository = tourRepository,
        _tourService = tourService,
        _activityLogSink = activityLogSink;

  final PickingRepository _pickingRepository;
  final TourRepository _tourRepository;
  final TourService _tourService;
  final ActivityLogSink _activityLogSink;

  /// Ouvre (ou reprend) une session de picking pour une tournée.
  ///
  /// Charge automatiquement la liste des produits, leur ordre, et leur
  /// état (Directive, "Chargement"). Démarre la tournée si c'est la
  /// première ouverture (Téléchargée → En cours, via le Module 3), ou
  /// restitue exactement l'état existant si elle est déjà en cours —
  /// c'est ce mécanisme qui implémente la reprise automatique.
  Future<Result<PickingSession>> openSession(String tourId) async {
    final startResult = await _tourService.startOrResume(tourId);

    if (startResult case Failure<Tour>(exception: final exception)) {
      return Result.failure(exception);
    }
    final tour = (startResult as Success<Tour>).value;

    final produits = await _pickingRepository.loadProducts(tourId);
    return Result.success(_buildSession(tour: tour, produits: produits));
  }

  /// Applique la validation d'un produit (Directive, "Validation") :
  /// enregistre localement, met à jour la progression, et renvoie la
  /// session déjà positionnée sur le produit suivant. Aucune étape
  /// intermédiaire, aucun retour manuel requis.
  Future<Result<PickingSession>> validateCurrentProduct({
    required String tourId,
    required String productLineId,
    required ProductState etat,
    int? quantiteCollectee,
  }) async {
    await _pickingRepository.applyValidation(
      tourId: tourId,
      productLineId: productLineId,
      etat: etat,
      quantiteCollectee: quantiteCollectee,
    );

    final tour = await _tourRepository.findById(tourId);
    if (tour == null) {
      return const Result.failure(ValidationException('Tournée introuvable.'));
    }

    final produits = await _pickingRepository.loadProducts(tourId);
    AppLogger.event(
      'Produit $productLineId validé ($etat) — '
      '${produits.where((p) => p.etat.estTraite).length}/${produits.length}',
      tag: 'PickingService',
    );

    PickingProduct? produit;
    for (final p in produits) {
      if (p.id == productLineId) {
        produit = p;
        break;
      }
    }
    await _activityLogSink.record(
      userId: tour.preparateurId,
      level: _niveauPour(etat),
      message: _messagePourValidation(etat, produit?.nom),
    );

    return Result.success(_buildSession(tour: tour, produits: produits));
  }

  /// Point d'entrée "Produit introuvable" (Directive, "Produit
  /// introuvable") : fait uniquement passer le produit à l'état
  /// [ProductState.introuvable]. L'écran de choix du coursier — et donc
  /// la transition vers [ProductState.envoyeAuCoursier] — arrive au
  /// Module 5 ; ce service ne l'implémente pas.
  Future<Result<PickingSession>> markCurrentProductIntrouvable({
    required String tourId,
    required String productLineId,
  }) {
    return validateCurrentProduct(
      tourId: tourId,
      productLineId: productLineId,
      etat: ProductState.introuvable,
    );
  }

  ActivityLevel _niveauPour(ProductState etat) {
    switch (etat) {
      case ProductState.collecte:
      case ProductState.partiellementCollecte:
        return ActivityLevel.succes;
      case ProductState.introuvable:
        return ActivityLevel.avertissement;
      case ProductState.envoyeAuCoursier:
      case ProductState.aRecuperer:
        return ActivityLevel.neutre;
    }
  }

  String _messagePourValidation(ProductState etat, String? nomProduit) {
    final nom = nomProduit ?? 'Produit';
    switch (etat) {
      case ProductState.collecte:
        return '$nom récupéré';
      case ProductState.partiellementCollecte:
        return '$nom récupéré partiellement';
      case ProductState.introuvable:
        return '$nom introuvable';
      case ProductState.envoyeAuCoursier:
        return '$nom envoyé au coursier';
      case ProductState.aRecuperer:
        return '$nom remis à collecter';
    }
  }

  PickingSession _buildSession({
    required Tour tour,
    required List<PickingProduct> produits,
  }) {
    PickingProduct? produitCourant;
    for (final produit in produits) {
      if (produit.etat == ProductState.aRecuperer) {
        produitCourant = produit;
        break;
      }
    }

    final traites = produits.where((p) => p.etat.estTraite).length;

    return PickingSession(
      tour: tour,
      produits: produits,
      produitCourant: produitCourant,
      progression: PickingProgress(traites: traites, total: produits.length),
    );
  }
}
