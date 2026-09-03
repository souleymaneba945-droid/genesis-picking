import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/activity/activity_log_entry.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/activity/activity_level_style.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';

/// Écran d'historique complet — un seul et même écran pour le Préparateur
/// et le Coursier (Refonte "historique de tous les traitements"), filtré
/// sur [userId] : chaque compte ne voit jamais que sa propre activité.
///
/// Écran secondaire atteint par navigation : garde une AppBar classique
/// avec retour, comme les autres écrans de ce type (voir plan de refonte,
/// "Hors périmètre").
class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<ActivityHistoryScreen> createState() =>
      _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends ConsumerState<ActivityHistoryScreen> {
  late Future<List<ActivityLogEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _load();
  }

  Future<List<ActivityLogEntry>> _load() {
    return ref
        .read(activityLogRepositoryProvider)
        .listForUser(widget.userId, limit: 200);
  }

  void _refresh() => setState(() => _entriesFuture = _load());

  Future<void> _confirmerPurge() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Purger l\'historique ?'),
        content: const Text(
          'Toutes les entrées de cet historique seront définitivement '
          'effacées. Cela n\'affecte ni vos tournées, ni vos produits, '
          'ni vos demandes en cours.',
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

    await ref.read(activityLogRepositoryProvider).purgeForUser(widget.userId);
    if (!mounted) return;
    _refresh();
    AppSnackbar.showSuccess(context, 'Historique purgé.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            onPressed: _confirmerPurge,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Purger l\'historique',
          ),
        ],
      ),
      body: FutureBuilder<List<ActivityLogEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger l\'historique.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacingXl),
                child: Text(
                  'Aucune activité pour le moment.',
                  style: AppTypography.secondaryLabel,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _entriesFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimensions.spacingSm),
              itemBuilder: (context, index) =>
                  _ActivityTile(entry: entries[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final ActivityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(entry.level.icone, color: entry.level.couleur),
        title: Text(entry.message, style: AppTypography.body),
        subtitle: Text(_formatDate(entry.dateHeure)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} à '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
