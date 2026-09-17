import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/activity/recent_activity_card.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/widgets/status/stat_card.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/courier/presentation/my_courier_requests_screen.dart';
import 'package:genesis_picking/features/picking/presentation/picking_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_action_button.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_status_badge.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

/// Onglet "Accueil" du Préparateur (Refonte UI).
///
/// Salue le préparateur et met en avant SA tournée active dans une carte
/// unique, très visuelle — l'écran que le préparateur voit en premier en
/// arrivant, avant même de choisir quoi que ce soit. La liste complète des
/// tournées (s'il y en a plusieurs) reste dans l'onglet "Ma tournée".
///
/// Source de donnée : [toursForPreparateurProvider] — même flux "en
/// direct" partagé que [MyToursScreen] (voir ce provider) : les deux
/// onglets restent automatiquement synchronisés entre eux.
///
/// Modernisation visuelle (12/09/2026, maquette v0.dev fournie par
/// l'utilisateur) : grille de 4 statistiques + bandeau d'alerte coursier
/// ajoutés au-dessus de la carte de tournée existante — toutes deux
/// calculées à partir de données déjà chargées ailleurs dans l'app
/// ([toursForPreparateurProvider], `CourierService.listRequestsForPreparateur`),
/// jamais de chiffre inventé.
class PreparateurHomeTab extends ConsumerStatefulWidget {
  const PreparateurHomeTab({super.key});

  @override
  ConsumerState<PreparateurHomeTab> createState() => _PreparateurHomeTabState();
}

class _PreparateurHomeTabState extends ConsumerState<PreparateurHomeTab> {
  bool _isDownloading = false;
  Future<int>? _demandesEnAttenteFuture;

  /// À appeler après toute écriture LOCALE (téléchargement) qui ne serait
  /// pas automatiquement reflétée par le flux distant — voir la même note
  /// dans `MyToursScreen`.
  void _invalider() {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    ref.invalidate(toursForPreparateurProvider(session.userId));
  }

  Future<int> _chargerDemandesEnAttente(String preparateurId) async {
    final demandes = await ref
        .read(courierServiceProvider)
        .listRequestsForPreparateur(preparateurId);
    return demandes
        .where(
          (d) =>
              d.etat != CourierRequestStatus.traitee &&
              d.etat != CourierRequestStatus.terminee,
        )
        .length;
  }

  /// La tournée à mettre en avant : en cours en priorité, puis
  /// téléchargée, puis disponible — jamais une tournée déjà terminée.
  Tour? _tourActive(List<Tour> tours) {
    for (final statut in [
      TourStatus.enCours,
      TourStatus.telechargee,
      TourStatus.disponible,
    ]) {
      for (final tour in tours) {
        if (tour.statut == statut) return tour;
      }
    }
    return null;
  }

  Future<void> _download(Tour tour) async {
    setState(() => _isDownloading = true);
    final result = await ref.read(tourServiceProvider).downloadTour(tour.id);
    if (!mounted) return;
    setState(() => _isDownloading = false);
    result.when(
      success: (_) => _invalider(),
      failure: (exception) =>
          AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception)),
    );
  }

  void _startOrResume(Tour tour) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PickingScreen(tourId: tour.id)))
        .then((_) => _invalider());
  }

  void _voirVerifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _VerificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final asyncTours = session == null
        ? const AsyncValue<List<Tour>>.data([])
        : ref.watch(toursForPreparateurProvider(session.userId));

    _demandesEnAttenteFuture ??=
        session == null ? Future.value(0) : _chargerDemandesEnAttente(session.userId);

    return RefreshIndicator(
      onRefresh: () async {
        _invalider();
        if (session != null) {
          await ref.read(toursForPreparateurProvider(session.userId).future);
          setState(() {
            _demandesEnAttenteFuture = _chargerDemandesEnAttente(session.userId);
          });
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.spacingLg,
          AppDimensions.spacingSm,
          AppDimensions.spacingLg,
          AppDimensions.spacingLg,
        ),
        children: [
          const Text('Bonjour,', style: AppTypography.secondaryLabel),
          Text(
            '${session?.displayName ?? ''} 👋',
            style: AppTypography.greetingName,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          const Text(
            'Voici votre activité de préparation du jour.',
            style: AppTypography.secondaryLabel,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          asyncTours.when(
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            data: (tours) => _StatsGrid(tours: tours),
          ),
          FutureBuilder<int>(
            future: _demandesEnAttenteFuture,
            builder: (context, snapshot) {
              // En cas d'erreur, pas de bandeau plutôt qu'un compte à 0
              // trompeur (voir revue Cursor du 16/09/2026, §FutureBuilder
              // sans hasError) — ce bandeau reste secondaire, une erreur
              // silencieuse ici est préférable à un message d'erreur
              // intrusif pour une simple alerte de confort.
              if (snapshot.hasError) return const SizedBox.shrink();
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
                child: _AlertCard(count: count, onTap: _voirVerifications),
              );
            },
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          const Text('Commande en cours', style: AppTypography.sectionTitle),
          const SizedBox(height: AppDimensions.spacingSm),
          asyncTours.when(
            error: (_, __) => const _EmptyCard(
              message: 'Impossible de charger votre tournée.',
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            data: (tours) {
              final tour = _tourActive(tours);
              if (tour == null) {
                return const _EmptyCard(
                  message: 'Aucune tournée pour le moment.',
                );
              }
              return _ActiveTourCard(
                tour: tour,
                isLoading: _isDownloading,
                onDownload: () => _download(tour),
                onStartOrResume: () => _startOrResume(tour),
              );
            },
          ),
          if (session != null) ...[
            const SizedBox(height: AppDimensions.spacingLg),
            RecentActivityCard(userId: session.userId),
          ],
        ],
      ),
    );
  }
}

/// Grille 2x2 de statistiques du jour — mêmes libellés que la maquette,
/// chiffres réels : "À faire" (disponible + téléchargée), "En cours",
/// "Terminées", "Produits validés" (cumul sur les tournées visibles).
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.tours});

  final List<Tour> tours;

  @override
  Widget build(BuildContext context) {
    int compte(TourStatus s) => tours.where((t) => t.statut == s).length;
    final aFaire = compte(TourStatus.disponible) + compte(TourStatus.telechargee);
    final enCours = compte(TourStatus.enCours);
    final terminees = compte(TourStatus.terminee);
    final produitsValides = tours.fold<int>(0, (s, t) => s + t.produitsTraites);

    // Réutilise `StatCard`, déjà partagée par les tableaux de bord Coursier
    // et Administrateur — jamais une tuile de statistique réinventée par
    // écran (voir sa documentation).
    //
    // Deux `Row` de `Expanded`, jamais un `GridView.count` à
    // `childAspectRatio` fixe (bug constaté 13/09/2026 : sur une fenêtre
    // large — desktop, tablette —, une largeur de colonne élevée combinée
    // à un ratio fixe donne des tuiles démesurément hautes, avec un grand
    // vide sous le chiffre). Une `Row` d'`Expanded` garde la hauteur
    // dictée par le contenu de `StatCard` lui-même, quelle que soit la
    // largeur de l'écran.
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(value: '$aFaire', label: 'À faire', icon: Icons.assignment_outlined, color: AppColors.neutral),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: StatCard(value: '$enCours', label: 'En cours', icon: Icons.schedule, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Row(
          children: [
            Expanded(
              child: StatCard(value: '$terminees', label: 'Terminées', icon: Icons.inventory_2_outlined, color: AppColors.success),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: StatCard(value: '$produitsValides', label: 'Produits validés', icon: Icons.fact_check_outlined, color: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bandeau d'alerte : demandes coursier envoyées par CE préparateur et
/// toujours en attente de réponse (voir `_chargerDemandesEnAttente`).
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count vérification${count > 1 ? 's' : ''} coursier en attente',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningText,
                      ),
                    ),
                    const Text(
                      'Suivez les produits introuvables signalés',
                      style: AppTypography.secondaryLabel,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.warningText),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationsPage extends StatelessWidget {
  const _VerificationsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SafeArea(child: MyCourierRequestsScreen()));
  }
}

class _ActiveTourCard extends StatelessWidget {
  const _ActiveTourCard({
    required this.tour,
    required this.isLoading,
    required this.onDownload,
    required this.onStartOrResume,
  });

  final Tour tour;
  final bool isLoading;
  final VoidCallback onDownload;
  final VoidCallback onStartOrResume;

  @override
  Widget build(BuildContext context) {
    final progression = tour.nombreTotalProduits == 0
        ? 0.0
        : tour.produitsTraites / tour.nombreTotalProduits;
    final (label, bg, fg) = TourStatusBadge.appearanceFor(tour.statut);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(tour.numeroTournee, style: AppTypography.sectionTitle),
                ),
                StatusPill(label: label, background: bg, foreground: fg),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${tour.nombreTotalProduits} produits',
              style: AppTypography.secondaryLabel,
            ),
            if (tour.estTeleChargeeLocalement) ...[
              const SizedBox(height: AppDimensions.spacingLg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tour.produitsTraites}/${tour.nombreTotalProduits} produits validés',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${(progression * 100).round()}%',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.cornerRadiusPill),
                child: LinearProgressIndicator(
                  value: progression,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceAlt,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLg),
            TourActionButton(
              tour: tour,
              isLoading: isLoading,
              onDownload: onDownload,
              onStartOrResume: onStartOrResume,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXl),
        child: Center(
          child: Text(
            message,
            style: AppTypography.secondaryLabel,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
