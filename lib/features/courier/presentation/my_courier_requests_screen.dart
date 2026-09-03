import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Onglet "Vérifications" du Préparateur (Refonte UI) — suivi des demandes
/// qu'il a envoyées au coursier (Directive, "Retour préparateur") :
/// "le préparateur reçoit immédiatement la mise à jour (ou dès la
/// prochaine synchronisation si hors connexion)".
///
/// N'affiche que l'état et, une fois disponible, le résultat — aucune
/// information supplémentaire n'est requise par la Directive.
class MyCourierRequestsScreen extends ConsumerStatefulWidget {
  const MyCourierRequestsScreen({super.key});

  @override
  ConsumerState<MyCourierRequestsScreen> createState() =>
      _MyCourierRequestsScreenState();
}

class _MyCourierRequestsScreenState
    extends ConsumerState<MyCourierRequestsScreen> {
  late Future<List<CourierRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _load();
  }

  Future<List<CourierRequest>> _load() {
    final session = ref.read(sessionProvider);
    if (session == null) {
      // Défensif : voir my_tours_screen.dart pour la même justification.
      return Future.value(const []);
    }
    return ref
        .read(courierServiceProvider)
        .listRequestsForPreparateur(session.userId);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _requestsFuture = _load());
        await _requestsFuture;
      },
      child: FutureBuilder<List<CourierRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger vos demandes.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingLg,
              AppDimensions.spacingSm,
              AppDimensions.spacingLg,
              AppDimensions.spacingLg,
            ),
            children: [
              const Text('Vérifications', style: AppTypography.screenTitle),
              const SizedBox(height: AppDimensions.spacingLg),
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.spacingXl),
                  child: Center(
                    child: Text('Aucune demande envoyée pour le moment.'),
                  ),
                )
              else
                for (final request in requests) ...[
                  _RequestCard(request: request),
                  const SizedBox(height: AppDimensions.spacingSm),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final CourierRequest request;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Row(
          children: [
            Icon(_statusIcon(request.etat), color: color),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(request.etat),
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (request.resultat != null)
                    Text(
                      request.resultat == CourierRequestResult.retrouve
                          ? 'Produit retrouvé'
                          : 'Produit non retrouvé',
                      style: AppTypography.secondaryLabel,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(CourierRequestStatus etat) {
    return switch (etat) {
      CourierRequestStatus.creee => 'Créée',
      CourierRequestStatus.enAttente => 'En attente (coursier hors ligne)',
      CourierRequestStatus.recue => 'Reçue par le coursier',
      CourierRequestStatus.acceptee => 'En cours de traitement',
      CourierRequestStatus.traitee => 'Traitée',
      CourierRequestStatus.terminee => 'Terminée',
    };
  }

  IconData _statusIcon(CourierRequestStatus etat) {
    return switch (etat) {
      CourierRequestStatus.terminee => Icons.check_circle,
      CourierRequestStatus.traitee => Icons.check_circle_outline,
      _ => Icons.hourglass_top_outlined,
    };
  }

  Color _statusColor(CourierRequest request) {
    if (request.resultat == CourierRequestResult.nonRetrouve) {
      return AppColors.error;
    }
    if (request.etat == CourierRequestStatus.terminee ||
        request.etat == CourierRequestStatus.traitee) {
      return AppColors.success;
    }
    return AppColors.neutral;
  }
}
