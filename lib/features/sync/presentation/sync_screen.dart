import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/features/sync/presentation/sync_controller.dart';

/// Écran Synchronisation (Directive Module 6).
///
/// Affiche UNIQUEMENT ce qui est demandé : dernière synchronisation,
/// nombre d'éléments en attente, état actuel, bouton "Synchroniser
/// maintenant". Rien d'autre — pas de détail technique, pas de liste
/// d'opérations.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Impossible de charger l\'état de synchronisation.'),
        ),
        data: (state) => Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(
                label: 'Dernière synchronisation',
                value: _formatLastRun(state.lastRun?.finishedAt),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              _InfoRow(
                label: 'Éléments en attente',
                value: '${state.pendingCount}',
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              _InfoRow(
                label: 'État actuel',
                value: _currentStateLabel(state),
                valueColor: _currentStateColor(state),
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              PrimaryButton(
                label: 'Synchroniser maintenant',
                isLoading: state.isRunning,
                onPressed: () =>
                    ref.read(syncControllerProvider.notifier).synchronizeNow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _currentStateLabel(SyncScreenState state) {
    if (state.isRunning) return 'Synchronisation en cours';
    if (!state.isOnline) return 'Hors connexion';
    if (state.pendingCount == 0) return 'À jour';
    return 'En attente de synchronisation';
  }

  Color _currentStateColor(SyncScreenState state) {
    if (state.isRunning) return AppColors.warning;
    if (!state.isOnline) return AppColors.neutral;
    if (state.pendingCount == 0) return AppColors.success;
    return AppColors.warning;
  }

  String _formatLastRun(DateTime? date) {
    if (date == null) return 'Jamais';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    return 'Il y a ${diff.inDays} j';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.secondaryLabel),
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
