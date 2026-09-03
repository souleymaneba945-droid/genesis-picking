import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/sync/firestore/firestore_providers.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';

enum _DiagnosticStatus { ok, warning, error }

class _DiagnosticItem {
  const _DiagnosticItem({
    required this.label,
    required this.status,
    required this.detail,
  });

  final String label;
  final _DiagnosticStatus status;
  final String detail;
}

/// Écran "Diagnostic" — teste et affiche concrètement ce qui pourrait
/// rendre l'appli lente, plutôt qu'une simple promesse de rapidité :
/// vitesse réelle de connexion au serveur, état de la base locale, et
/// nombre d'actions encore en attente de synchronisation. Chaque mesure
/// utilise une infrastructure déjà en place (mêmes providers que le reste
/// de l'appli) — aucune nouvelle collection Firestore créée pour ce test
/// (une collection non couverte par `firestore.rules` échouerait
/// silencieusement en "permission-denied", piège déjà rencontré une fois
/// sur `courier_requests` — voir CLAUDE.md), on réutilise la collection
/// `users` (déjà ouverte en lecture) juste pour mesurer un aller-retour.
class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  late Future<List<_DiagnosticItem>> _resultsFuture;

  @override
  void initState() {
    super.initState();
    _resultsFuture = _runDiagnostics();
  }

  void _relancer() {
    setState(() => _resultsFuture = _runDiagnostics());
  }

  Future<List<_DiagnosticItem>> _runDiagnostics() async {
    return [
      await _testConnexionServeur(),
      await _testBaseLocale(),
      await _testFileSynchronisation(),
    ];
  }

  Future<_DiagnosticItem> _testConnexionServeur() async {
    final stopwatch = Stopwatch()..start();
    try {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 20));
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      return _DiagnosticItem(
        label: 'Connexion au serveur',
        status: ms < 1500
            ? _DiagnosticStatus.ok
            : ms < 5000
                ? _DiagnosticStatus.warning
                : _DiagnosticStatus.error,
        detail: '$ms ms',
      );
    } catch (_) {
      return const _DiagnosticItem(
        label: 'Connexion au serveur',
        status: _DiagnosticStatus.error,
        detail: 'Aucune réponse (pas de réseau, ou serveur inaccessible)',
      );
    }
  }

  Future<_DiagnosticItem> _testBaseLocale() async {
    final stopwatch = Stopwatch()..start();
    try {
      await ref
          .read(localDatabaseProvider)
          .customSelect('SELECT 1')
          .getSingleOrNull();
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      return _DiagnosticItem(
        label: 'Base de données locale',
        status: ms < 200 ? _DiagnosticStatus.ok : _DiagnosticStatus.warning,
        detail: '$ms ms',
      );
    } catch (_) {
      return const _DiagnosticItem(
        label: 'Base de données locale',
        status: _DiagnosticStatus.error,
        detail: 'Inaccessible',
      );
    }
  }

  Future<_DiagnosticItem> _testFileSynchronisation() async {
    try {
      final pending = await ref.read(syncQueueProvider).pendingEvents();
      final count = pending.length;
      return _DiagnosticItem(
        label: 'Actions en attente de synchronisation',
        status: count == 0
            ? _DiagnosticStatus.ok
            : count < 20
                ? _DiagnosticStatus.warning
                : _DiagnosticStatus.error,
        detail: count == 0 ? 'Aucune' : '$count',
      );
    } catch (_) {
      return const _DiagnosticItem(
        label: 'Actions en attente de synchronisation',
        status: _DiagnosticStatus.error,
        detail: 'Impossible à vérifier',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic'),
        actions: [
          IconButton(
            onPressed: _relancer,
            icon: const Icon(Icons.refresh),
            tooltip: 'Relancer le diagnostic',
          ),
        ],
      ),
      body: FutureBuilder<List<_DiagnosticItem>>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          final ensembleOk = items.every((i) => i.status == _DiagnosticStatus.ok);

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            children: [
              Card(
                color: ensembleOk ? AppColors.success.withValues(alpha: 0.08) : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.cardPadding),
                  child: Row(
                    children: [
                      Icon(
                        ensembleOk ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                        color: ensembleOk ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Expanded(
                        child: Text(
                          ensembleOk
                              ? 'Tout fonctionne normalement.'
                              : 'Au moins un point mérite votre attention ci-dessous.',
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              for (final item in items) ...[
                _DiagnosticTile(item: item),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({required this.item});

  final _DiagnosticItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.status) {
      _DiagnosticStatus.ok => (Icons.check_circle_outline, AppColors.success),
      _DiagnosticStatus.warning => (Icons.warning_amber_outlined, AppColors.warning),
      _DiagnosticStatus.error => (Icons.error_outline, AppColors.error),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(item.label, style: AppTypography.body),
        subtitle: Text(item.detail, style: AppTypography.secondaryLabel),
      ),
    );
  }
}
