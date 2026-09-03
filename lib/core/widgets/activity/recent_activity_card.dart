import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/activity/activity_log_entry.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/activity/activity_history_screen.dart';
import 'package:genesis_picking/core/widgets/activity/activity_level_style.dart';

/// Carte "Activité récente" des tableaux de bord Préparateur/Coursier —
/// aperçu des 3 dernières entrées + lien "Voir tout" vers
/// [ActivityHistoryScreen] (qui expose la purge). Un seul widget partagé
/// pour les deux rôles : seul [userId] change.
class RecentActivityCard extends ConsumerStatefulWidget {
  const RecentActivityCard({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<RecentActivityCard> createState() =>
      _RecentActivityCardState();
}

class _RecentActivityCardState extends ConsumerState<RecentActivityCard> {
  late Future<List<ActivityLogEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = ref
        .read(activityLogRepositoryProvider)
        .listForUser(widget.userId, limit: 3);
  }

  void _ouvrirHistorique() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ActivityHistoryScreen(userId: widget.userId),
          ),
        )
        .then((_) {
          if (!mounted) return;
          setState(() {
            _entriesFuture = ref
                .read(activityLogRepositoryProvider)
                .listForUser(widget.userId, limit: 3);
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Activité récente',
                    style: AppTypography.chipLabel.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _ouvrirHistorique,
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            FutureBuilder<List<ActivityLogEntry>>(
              future: _entriesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Impossible de charger l\'activité.',
                    style: AppTypography.secondaryLabel,
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingMd,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingSm,
                    ),
                    child: Text(
                      'Aucune activité pour le moment.',
                      style: AppTypography.secondaryLabel,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacingXs,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              entry.level.icone,
                              color: entry.level.couleur,
                              size: 20,
                            ),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Expanded(
                              child: Text(
                                entry.message,
                                style: AppTypography.body,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
