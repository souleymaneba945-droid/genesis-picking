import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/widgets/chips/app_filter_chip.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/courier/presentation/widgets/courier_quick_picker_sheet.dart';
import 'package:genesis_picking/features/picking/data/picking_product.dart';
import 'package:genesis_picking/features/picking/data/product_state.dart';
import 'package:genesis_picking/features/picking/domain/picking_session.dart';
import 'package:genesis_picking/features/picking/presentation/picking_controller.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/live_duration_chip.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/picking_product_row.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/progress_bar.dart';
import 'package:genesis_picking/features/picking/presentation/widgets/tour_complete_view.dart';

/// Filtre d'affichage de la liste de picking (Modernisation visuelle,
/// 13/09/2026, maquette v0.dev) — purement local à cet écran, ne change
/// jamais l'ordre ni le contenu de [PickingSession.produits] : un simple
/// sous-ensemble affiché, jamais une nouvelle requête ni une mutation.
enum _FiltrePicking { tous, restants, valides, introuvables }

/// Écran de picking — LE moteur de GENESIS PICKING.
///
/// Liste complète des produits de la tournée, même disposition que la
/// picking list papier/PDF déjà utilisée sur le terrain (photo, quantité,
/// emplacement, produit) — plus rapide à parcourir d'un coup d'œil et
/// plus familier pour le préparateur qu'un produit isolé à la fois.
/// Validation directe sur chaque ligne. Aucune requête réseau : tout
/// provient de la session déjà chargée localement par [PickingController].
///
/// Modernisation visuelle (13/09/2026) : recherche + filtres à puces
/// ajoutés en tête de liste — ce choix de garder TOUTE la liste visible
/// (plutôt qu'un produit à la fois, comme une autre maquette v0.dev
/// envisageait) a été explicitement confirmé par l'utilisateur : sur une
/// tournée de 200+ produits, naviguer un par un serait bien plus lent que
/// de tout voir d'un coup — décision déjà actée le 03/09/2026 suite à un
/// retour terrain, reconduite ici.
class PickingScreen extends ConsumerStatefulWidget {
  const PickingScreen({required this.tourId, super.key});

  final String tourId;

  @override
  ConsumerState<PickingScreen> createState() => _PickingScreenState();
}

class _PickingScreenState extends ConsumerState<PickingScreen> {
  final _rechercheController = TextEditingController();
  String _recherche = '';
  _FiltrePicking _filtre = _FiltrePicking.tous;

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  bool _correspondFiltre(PickingProduct produit) {
    return switch (_filtre) {
      _FiltrePicking.tous => true,
      _FiltrePicking.restants => produit.etat == ProductState.aRecuperer,
      _FiltrePicking.valides =>
        produit.etat == ProductState.collecte ||
            produit.etat == ProductState.partiellementCollecte,
      _FiltrePicking.introuvables =>
        produit.etat == ProductState.introuvable ||
            produit.etat == ProductState.envoyeAuCoursier,
    };
  }

  bool _correspondRecherche(PickingProduct produit) {
    if (_recherche.isEmpty) return true;
    final q = _recherche.toLowerCase();
    return produit.nom.toLowerCase().contains(q) ||
        (produit.description?.toLowerCase().contains(q) ?? false);
  }

  String _libelleFiltre(_FiltrePicking f) => switch (f) {
        _FiltrePicking.tous => 'Tous',
        _FiltrePicking.restants => 'Restants',
        _FiltrePicking.valides => 'Validés',
        _FiltrePicking.introuvables => 'Introuvables',
      };

  int _compteFiltre(_FiltrePicking f, List<PickingProduct> produits) {
    return switch (f) {
      _FiltrePicking.tous => produits.length,
      _FiltrePicking.restants =>
        produits.where((p) => p.etat == ProductState.aRecuperer).length,
      _FiltrePicking.valides => produits
          .where(
            (p) =>
                p.etat == ProductState.collecte ||
                p.etat == ProductState.partiellementCollecte,
          )
          .length,
      _FiltrePicking.introuvables => produits
          .where(
            (p) =>
                p.etat == ProductState.introuvable ||
                p.etat == ProductState.envoyeAuCoursier,
          )
          .length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final asyncSession = ref.watch(pickingControllerProvider(widget.tourId));
    final dateDebut = asyncSession.valueOrNull?.tour.dateDebut;

    return Scaffold(
      appBar: AppBar(
        title: Text(asyncSession.valueOrNull?.tour.numeroTournee ?? 'Picking'),
        actions: [
          if (dateDebut != null) ...[
            LiveDurationChip(depuis: dateDebut),
            const SizedBox(width: AppDimensions.spacingMd),
          ],
        ],
      ),
      body: asyncSession.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Text(
              error is AppException
                  ? ErrorHandler.userMessageFor(error)
                  : 'Une erreur est survenue.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (session) {
          if (session.estTerminee) {
            return TourCompleteView(tourId: widget.tourId, session: session);
          }

          final produitsFiltres = session.produits
              .where(_correspondFiltre)
              .where(_correspondRecherche)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  0,
                ),
                child: ProgressBar(progression: session.progression),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  0,
                ),
                child: TextField(
                  controller: _rechercheController,
                  onChanged: (value) => setState(() => _recherche = value),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit ou une réf.',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _recherche.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _rechercheController.clear();
                              setState(() => _recherche = '');
                            },
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingSm,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusMd),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
                child: Row(
                  children: [
                    for (final f in _FiltrePicking.values) ...[
                      AppFilterChip(
                        label: _libelleFiltre(f),
                        count: _compteFiltre(f, session.produits),
                        selected: _filtre == f,
                        onTap: () => setState(() => _filtre = f),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Expanded(
                child: produitsFiltres.isEmpty
                    ? const Center(child: Text('Aucun produit dans ce filtre.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingMd,
                        ),
                        itemCount: produitsFiltres.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppDimensions.spacingSm),
                        itemBuilder: (context, index) {
                          final produit = produitsFiltres[index];
                          return PickingProductRow(
                            produit: produit,
                            onValider: () => _valider(context, ref, produit),
                            onIntrouvable: () => _introuvable(ref, produit),
                            onEnvoyerCoursier: () =>
                                _envoyerCoursier(context, ref, produit),
                            onAnnuler: (productLineId) => ref
                                .read(pickingControllerProvider(widget.tourId).notifier)
                                .annulerValidation(productLineId),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _valider(
    BuildContext context,
    WidgetRef ref,
    PickingProduct produit,
  ) async {
    final controller = ref.read(pickingControllerProvider(widget.tourId).notifier);
    await controller.validerProduit(
      produit.id,
      quantiteCollectee: produit.quantiteDemandee,
    );
    if (context.mounted) _reportErrorIfAny(context, ref);
  }

  /// 3ᵉ action de la ligne (🚚) : envoi direct à un coursier, produit
  /// entièrement introuvable (pas de qualification de quantité partielle
  /// — pour ça, [_introuvable] reste le chemin normal).
  Future<void> _envoyerCoursier(
    BuildContext context,
    WidgetRef ref,
    PickingProduct produit,
  ) async {
    final session = ref.read(sessionProvider);
    if (session == null) return; // défensif : le guard de navigation gère la session.

    final envoye = await showCourierQuickPickerSheet(
      context,
      preparateurId: session.userId,
      tourId: widget.tourId,
      productLineId: produit.id,
      quantiteDemandee: produit.quantiteDemandee,
      emplacement: produit.emplacement,
      produitNom: produit.nom,
      produitImageUrl: produit.imageUrl,
    );

    if (envoye != true || !context.mounted) return;

    await ref
        .read(pickingControllerProvider(widget.tourId).notifier)
        .marquerEnvoyeAuCoursier(produit.id);
  }

  /// Bouton ✕ de la ligne : un simple constat "pas encore trouvé", sans
  /// suite automatique — envoyer le produit à un coursier reste une action
  /// séparée et volontaire, voir le bouton 🚚 ([_envoyerCoursier]).
  Future<void> _introuvable(WidgetRef ref, PickingProduct produit) async {
    await ref
        .read(pickingControllerProvider(widget.tourId).notifier)
        .marquerIntrouvable(produit.id);
  }

  void _reportErrorIfAny(BuildContext context, WidgetRef ref) {
    final state = ref.read(pickingControllerProvider(widget.tourId));
    if (state.hasError) {
      final error = state.error;
      AppSnackbar.showError(
        context,
        error is AppException
            ? ErrorHandler.userMessageFor(error)
            : 'Une erreur est survenue.',
      );
    }
  }
}
