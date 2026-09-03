import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/activity/recent_activity_card.dart';
import 'package:genesis_picking/core/widgets/status/stat_card.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/courier/presentation/courier_controller.dart';

/// Onglet "Accueil" du Coursier (Refonte UI) — salue le coursier et met en
/// avant le nombre de demandes qui l'attendent, sans dupliquer la liste
/// détaillée déjà disponible dans l'onglet "Demandes".
class CoursierHomeTab extends ConsumerWidget {
  const CoursierHomeTab({super.key});

  static const Set<CourierRequestStatus> _etatsClos = {
    CourierRequestStatus.traitee,
    CourierRequestStatus.terminee,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final asyncRequests = ref.watch(courierControllerProvider);

    final ouvertes = asyncRequests.valueOrNull
            ?.where((r) => !_etatsClos.contains(r.request.etat))
            .length ??
        0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingSm,
        AppDimensions.spacingLg,
        AppDimensions.spacingLg,
      ),
      children: [
        Text('Bonjour ${session?.displayName ?? ''}', style: AppTypography.screenTitle),
        const SizedBox(height: AppDimensions.spacingLg),
        StatCard(
          value: '$ouvertes',
          label: ouvertes > 1 ? 'demandes en attente' : 'demande en attente',
          icon: Icons.support_agent,
          color: ouvertes > 0 ? AppColors.warning : AppColors.success,
        ),
        if (session != null) ...[
          const SizedBox(height: AppDimensions.spacingLg),
          RecentActivityCard(userId: session.userId),
        ],
      ],
    );
  }
}
