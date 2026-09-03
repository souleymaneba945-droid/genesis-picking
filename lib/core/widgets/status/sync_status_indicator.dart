import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/sync/sync_manager.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';

/// Indicateur d'état réseau/synchronisation, visible en permanence mais
/// discret (Document UX/UI, section 8) : jamais de pop-up, jamais de
/// blocage d'écran.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncManager = ref.watch(syncManagerProvider);

    return StreamBuilder<SyncState>(
      stream: syncManager.stateStream,
      initialData: syncManager.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? SyncState.offline;
        final (icon, color) = _appearanceFor(state);
        return Icon(icon, color: color, size: 18);
      },
    );
  }

  (IconData, Color) _appearanceFor(SyncState state) {
    return switch (state) {
      SyncState.synced => (Icons.cloud_done_outlined, AppColors.success),
      SyncState.pending => (Icons.cloud_upload_outlined, AppColors.warning),
      SyncState.syncing => (Icons.sync, AppColors.warning),
      SyncState.offline => (Icons.cloud_off_outlined, AppColors.neutral),
      SyncState.error => (Icons.error_outline, AppColors.error),
    };
  }
}
