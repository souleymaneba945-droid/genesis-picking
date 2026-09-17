import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/core/widgets/media/product_thumbnail.dart';
import 'package:genesis_picking/core/widgets/status/stat_card.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
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
/// Liste plate, fusionnée par produit (Module 5 v2, Rubrique 1) — jamais
/// groupée par préparateur : quand deux préparateurs différents signalent
/// le même produit introuvable (même référence exacte), le coursier voit
/// une seule entrée à traiter, pas deux demandes séparées à double emploi.
/// Le regroupement par préparateur envisagé initialement a été abandonné
/// sur demande explicite (08/09/2026) : reconnaître le produit compte
/// plus que savoir qui l'a demandé.
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
              .where((r) =>
                  _etatsClos.contains(r.request.etat) == widget.historique)
              .toList();
          // Filtrage (ouvertes/closes) TOUJOURS avant fusion : une demande
          // encore ouverte d'un préparateur ne doit jamais se retrouver
          // fusionnée avec une demande déjà close d'un autre pour le même
          // produit — les deux onglets restent strictement séparés.
          final groupes = groupCourierRequestsByProduct(filtered);

          // Les deux compteurs (Modernisation visuelle, 12/09/2026)
          // portent TOUJOURS sur `requests` au complet, jamais sur
          // `filtered` : contrairement au titre et à la liste, qui restent
          // propres à cet onglet, les tuiles rappellent le total sur les
          // deux onglets à la fois (elles ne changent donc pas selon
          // qu'on est sur "Demandes" ou "Historique").
          final aVerifier = requests
              .where((r) => !_etatsClos.contains(r.request.etat))
              .length;
          final traitees =
              requests.where((r) => _etatsClos.contains(r.request.etat)).length;

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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.cornerRadius),
                    ),
                    child: const Icon(Icons.local_shipping_outlined,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.historique ? 'Historique' : 'Vérifications',
                          style: AppTypography.sectionTitle,
                        ),
                        const Text(
                          'Produits à contrôler en rayon',
                          style: AppTypography.secondaryLabel,
                        ),
                      ],
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
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      value: '$aVerifier',
                      label: 'À vérifier',
                      icon: Icons.inventory_2_outlined,
                      color:
                          aVerifier > 0 ? AppColors.warning : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: StatCard(
                      value: '$traitees',
                      label: 'Traitées',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              if (groupes.isEmpty)
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
                for (final groupe in groupes) ...[
                  _MergedRequestCard(
                    groupe: groupe,
                    historique: widget.historique,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CourierRequestDetailScreen(
                            requestIds: groupe.requestIds,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        await ref
                            .read(courierControllerProvider.notifier)
                            .refresh();
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

/// Une entrée de la liste des missions du coursier — un produit, potentiellement
/// demandé par plusieurs préparateurs à la fois (badge "N préparateurs").
/// Même vignette produit ([ProductThumbnail]) que la ligne de picking du
/// préparateur, pour que le coursier reconnaisse le produit d'un coup
/// d'œil exactement comme sur la liste de picking, jamais une simple
/// ligne de statut sans image.
class _MergedRequestCard extends StatelessWidget {
  const _MergedRequestCard({
    required this.groupe,
    required this.historique,
    required this.onTap,
  });

  final MergedCourierRequest groupe;

  /// `true` sur l'onglet "Historique" : affiche le résultat plutôt qu'un
  /// bouton d'action (Modernisation visuelle, 12/09/2026).
  final bool historique;
  final VoidCallback onTap;

  /// La première demande du groupe sert de référence pour l'emplacement/
  /// l'horodatage : quand plusieurs préparateurs signalent le même produit
  /// (voir `groupCourierRequestsByProduct`), chacun a pu le faire depuis un
  /// emplacement différent (chacun sur sa propre tournée) — on affiche
  /// celui de la première demande, jamais une moyenne ni un mélange, et le
  /// badge "N préparateurs" déjà présent rappelle qu'il y en a d'autres.
  CourierRequestSummary get _premiere => groupe.requests.first;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _pillFor(_premiere.request.etat);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Toute la carte reste ouvrable (revoir le détail d'une demande déjà
        // traitée reste utile) — le bouton ci-dessous n'est qu'un raccourci
        // explicite vers la même action, jamais la seule façon d'y accéder.
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProductThumbnail(
                      imageUrl: groupe.produitImageUrl, taille: 48),
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
                        if (groupe.produitDescription != null &&
                            groupe.produitDescription!.isNotEmpty)
                          Text(
                            groupe.produitDescription!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.neutral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(groupe.produitNom, style: AppTypography.body),
                      ],
                    ),
                  ),
                  if (groupe.requests.length > 1) ...[
                    const SizedBox(width: AppDimensions.spacingSm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(
                            AppDimensions.cornerRadiusPill),
                      ),
                      child: Text(
                        '${groupe.requests.length} préparateurs',
                        style: AppTypography.secondaryLabel.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else
                    StatusPill(label: label, background: bg, foreground: fg),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacingSm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.cornerRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: _premiere.request.emplacement,
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.person_outline,
                      text: groupe.requests.length > 1
                          ? 'Demandé par ${_premiere.preparateurNom} et '
                              '${groupe.requests.length - 1} autre(s)'
                          : 'Demandé par ${_premiere.preparateurNom} · '
                              '${_heure(_premiere.request.dateCreation)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              if (historique)
                _ResultatLine(resultat: _premiere.request.resultat)
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.search),
                    label: Text(
                      _premiere.request.etat == CourierRequestStatus.acceptee
                          ? 'Continuer la vérification'
                          : 'Commencer la vérification',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _heure(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}';
  }

  /// (libellé, fond doux, couleur pleine) pour le badge de statut — mêmes
  /// tokens que `TourStatusBadge`/`StatusPill` partout ailleurs (Modernisation
  /// visuelle, 12/09/2026) : neutre tant qu'aucune action coursier n'a eu
  /// lieu, bleu dès qu'il l'a acceptée, vert une fois traitée.
  (String, Color, Color) _pillFor(CourierRequestStatus etat) {
    return switch (etat) {
      CourierRequestStatus.creee ||
      CourierRequestStatus.enAttente ||
      CourierRequestStatus.recue =>
        ('En attente', AppColors.surfaceAlt, AppColors.textSecondary),
      CourierRequestStatus.acceptee => (
          'Acceptée',
          AppColors.primarySoft,
          AppColors.primary
        ),
      CourierRequestStatus.traitee || CourierRequestStatus.terminee => (
          'Traitée',
          AppColors.successSoft,
          AppColors.success
        ),
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppDimensions.spacingXs),
        Expanded(child: Text(text, style: AppTypography.secondaryLabel)),
      ],
    );
  }
}

/// Résultat affiché sur l'onglet "Historique" — à la place du bouton
/// d'action, qui n'a plus lieu d'être une fois la demande traitée.
class _ResultatLine extends StatelessWidget {
  const _ResultatLine({required this.resultat});

  final CourierRequestResult? resultat;

  @override
  Widget build(BuildContext context) {
    final trouve = resultat == CourierRequestResult.retrouve;
    return Row(
      children: [
        Icon(
          trouve ? Icons.check_circle : Icons.cancel_outlined,
          size: 18,
          color: trouve ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Text(
          trouve ? 'Produit retrouvé' : 'Produit non retrouvé',
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
