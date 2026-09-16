import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/status/status_pill.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/administration/presentation/admin_history_screen.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Onglet "Suivi" de l'Administrateur (Refonte UI) — vue globale des
/// demandes coursier (Cahier des charges, écran 4.13 / PRD 3.5) : toutes
/// les demandes, tous préparateurs et coursiers confondus, avec leur état
/// — pour le suivi et la détection d'anomalies. L'historique des tournées
/// terminées (écran 3.6) reste accessible en un tap. Les statistiques de
/// demande (Rubrique 4ter) ont leur propre onglet ("Statistiques") depuis
/// le 16/09/2026, plus ici.
class AdminCourierRequestsScreen extends ConsumerWidget {
  const AdminCourierRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<CourierRequest>>(
      future: ref.read(administrationServiceProvider).toutesLesDemandes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Impossible de charger les demandes.'),
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
            Row(
              children: [
                const Expanded(
                  child: Text('Suivi', style: AppTypography.screenTitle),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminHistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Historique'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppDimensions.spacingXl),
                child: Center(child: Text('Aucune demande pour le moment.')),
              )
            else
              for (final request in requests) ...[
                _RequestCard(request: request),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
          ],
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final CourierRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantité ${request.quantiteDemandee} · ${request.emplacement}',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(request.dateCreation),
                    style: AppTypography.secondaryLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            StatusPill(
              label: _statusLabel(request.etat),
              background: _backgroundFor(request.etat),
              foreground: _colorFor(request.etat),
              icon: _iconFor(request.etat),
            ),
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

  IconData _iconFor(CourierRequestStatus etat) {
    return switch (etat) {
      CourierRequestStatus.terminee => Icons.check_circle,
      CourierRequestStatus.traitee => Icons.check_circle_outline,
      CourierRequestStatus.enAttente => Icons.wifi_off,
      _ => Icons.hourglass_top_outlined,
    };
  }

  Color _colorFor(CourierRequestStatus etat) {
    return switch (etat) {
      CourierRequestStatus.terminee => AppColors.success,
      CourierRequestStatus.traitee => AppColors.success,
      CourierRequestStatus.enAttente => AppColors.neutral,
      _ => AppColors.warningText,
    };
  }

  Color _backgroundFor(CourierRequestStatus etat) {
    return switch (etat) {
      CourierRequestStatus.terminee => AppColors.successSoft,
      CourierRequestStatus.traitee => AppColors.successSoft,
      CourierRequestStatus.enAttente => AppColors.surfaceAlt,
      _ => AppColors.warningSoft,
    };
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)} à ${two(date.hour)}:${two(date.minute)}';
  }
}
