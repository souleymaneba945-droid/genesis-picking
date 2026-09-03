import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/media/product_thumbnail.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/courier/data/courier_request_summary.dart';
import 'package:genesis_picking/features/courier/presentation/courier_controller.dart';
import 'package:genesis_picking/features/courier/presentation/courier_request_detail_screen.dart';

/// Liste des demandes du coursier connecté (Refonte UI), filtrée en
/// ouvertes ("Demandes") ou closes ("Historique") — les deux onglets de
/// [CoursierShell] partagent ce même widget et la même donnée
/// ([courierControllerProvider], déjà triée par priorité par
/// `CourierService`) : seul le filtre d'affichage change, jamais une
/// nouvelle requête ni une nouvelle règle métier.
///
/// Regroupée par préparateur (chaque nom est un en-tête dépliable) :
/// plusieurs préparateurs travaillent en parallèle et envoient chacun
/// leurs propres demandes — un coursier veut voir d'un coup d'œil tout ce
/// qu'UN préparateur donné lui a envoyé, pas une liste à plat mélangeant
/// tout le monde.
class CourierRequestsTab extends ConsumerStatefulWidget {
  const CourierRequestsTab({required this.historique, super.key});

  /// `false` : demandes encore actionnables. `true` : demandes déjà
  /// traitées ou terminées.
  final bool historique;

  @override
  ConsumerState<CourierRequestsTab> createState() => _CourierRequestsTabState();
}

class _CourierRequestsTabState extends ConsumerState<CourierRequestsTab> {
  static const Set<CourierRequestStatus> _etatsClos = {
    CourierRequestStatus.traitee,
    CourierRequestStatus.terminee,
  };

  final Set<String> _deplies = {};

  Future<void> _confirmerPurge() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Purger l\'historique ?'),
        content: const Text(
          'Toutes les demandes déjà traitées seront définitivement '
          'supprimées, sur cet appareil et sur celui de chaque '
          'préparateur concerné. Cela n\'affecte pas vos demandes encore '
          'en attente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Purger'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;

    final coursierId = ref.read(sessionProvider)!.userId;
    await ref.read(courierServiceProvider).purgeClosedForCoursier(coursierId);
    if (!mounted) return;
    await ref.read(courierControllerProvider.notifier).refresh();
    if (!mounted) return;
    AppSnackbar.showSuccess(context, 'Historique purgé.');
  }

  @override
  Widget build(BuildContext context) {
    final asyncRequests = ref.watch(courierControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(courierControllerProvider.notifier).refresh(),
      child: asyncRequests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Impossible de charger les demandes pour le moment.'),
        ),
        data: (requests) {
          final filtered = requests
              .where((r) => _etatsClos.contains(r.request.etat) == widget.historique)
              .toList();

          final parPreparateur = <String, List<CourierRequestSummary>>{};
          for (final r in filtered) {
            parPreparateur.putIfAbsent(r.preparateurNom, () => []).add(r);
          }
          final noms = parPreparateur.keys.toList()
            ..sort(
              (a, b) => parPreparateur[b]!.length.compareTo(parPreparateur[a]!.length),
            );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingLg,
              AppDimensions.spacingSm,
              AppDimensions.spacingLg,
              AppDimensions.spacingLg,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.historique ? 'Historique' : 'Demandes',
                      style: AppTypography.screenTitle,
                    ),
                  ),
                  if (widget.historique && filtered.isNotEmpty)
                    IconButton(
                      onPressed: _confirmerPurge,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: 'Purger l\'historique',
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              if (noms.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.spacingXl),
                  child: Center(
                    child: Text(
                      widget.historique
                          ? 'Aucune demande traitée pour le moment.'
                          : 'Aucune demande en attente.',
                    ),
                  ),
                )
              else
                for (final nom in noms) ...[
                  _PreparateurGroup(
                    nom: nom,
                    requests: parPreparateur[nom]!,
                    depli: _deplies.contains(nom),
                    onToggle: () => setState(() {
                      if (!_deplies.add(nom)) _deplies.remove(nom);
                    }),
                    rangDe: (id) => requests.indexWhere((r) => r.request.id == id) + 1,
                    onOpenRequest: (id) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CourierRequestDetailScreen(requestId: id),
                        ),
                      );
                      if (context.mounted) {
                        await ref.read(courierControllerProvider.notifier).refresh();
                      }
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// En-tête "nom du préparateur" dépliable — cliquer dessus affiche (ou
/// masque) toutes les demandes que CE préparateur a envoyées à ce
/// coursier.
class _PreparateurGroup extends StatelessWidget {
  const _PreparateurGroup({
    required this.nom,
    required this.requests,
    required this.depli,
    required this.onToggle,
    required this.rangDe,
    required this.onOpenRequest,
  });

  final String nom;
  final List<CourierRequestSummary> requests;
  final bool depli;
  final VoidCallback onToggle;
  final int Function(String requestId) rangDe;
  final void Function(String requestId) onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                    child: Icon(Icons.person_outline, size: 20),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: Text(
                      nom,
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${requests.length}',
                      style: AppTypography.secondaryLabel.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Icon(
                    depli ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.neutral,
                  ),
                ],
              ),
            ),
          ),
          if (depli)
            for (final r in requests) ...[
              const Divider(height: 1),
              _RequestRow(
                summary: r,
                rang: rangDe(r.request.id),
                onTap: () => onOpenRequest(r.request.id),
              ),
            ],
        ],
      ),
    );
  }
}

/// Une ligne de mission du coursier — même vignette produit
/// ([ProductThumbnail]) que la ligne de picking du préparateur, pour que
/// le coursier reconnaisse le produit d'un coup d'œil exactement comme
/// sur la liste de picking, jamais une simple ligne de statut sans image.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.summary,
    required this.rang,
    required this.onTap,
  });

  final CourierRequestSummary summary;
  final int rang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.cardPadding,
          vertical: AppDimensions.spacingSm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rang',
                style: AppTypography.secondaryLabel,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            ProductThumbnail(imageUrl: summary.produitImageUrl, taille: 48),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              // Même contenu, dans le même ordre, que la cellule
              // "Produit" de PickingProductRow : la référence (SKU -
              // code-barres) au-dessus du nom, sans troncature — le
              // coursier s'appuie dessus pour retrouver le produit,
              // jamais une présentation appauvrie par rapport au picking.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (summary.produitDescription != null &&
                      summary.produitDescription!.isNotEmpty)
                    Text(
                      summary.produitDescription!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.neutral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    summary.produitNom,
                    style: AppTypography.body,
                  ),
                  Text(
                    _statusLabel(summary.request.etat),
                    style: AppTypography.secondaryLabel,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral, size: 20),
          ],
        ),
      ),
    );
  }

  String _statusLabel(CourierRequestStatus etat) {
    return switch (etat) {
      CourierRequestStatus.creee => 'Créée',
      CourierRequestStatus.enAttente => 'En attente',
      CourierRequestStatus.recue => 'Reçue',
      CourierRequestStatus.acceptee => 'Acceptée',
      CourierRequestStatus.traitee => 'Traitée',
      CourierRequestStatus.terminee => 'Terminée',
    };
  }
}
