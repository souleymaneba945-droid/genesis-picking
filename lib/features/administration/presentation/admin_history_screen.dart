import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';

/// Écran Historique (Cahier des charges, écran 3.6) : tournées
/// terminées, consultables mais non modifiables (voir
/// `AdministrationService.reassignerTournee`, qui refuse explicitement
/// toute réassignation d'une tournée déjà terminée).
///
/// Sert aussi d'écran "analyse de vitesse" (03/09/2026) : chaque tournée
/// affiche sa durée réelle de picking (voir `Tour.dureeEcoulee`), avec
/// une moyenne par préparateur en tête d'écran — pas de nouvel onglet
/// dédié, cet écran couvrait déjà les tournées terminées.
class AdminHistoryScreen extends ConsumerWidget {
  const AdminHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: FutureBuilder<
          ({
            List<({Tour tour, String preparateurNom})> historique,
            List<({String preparateurNom, Duration dureeMoyenne, int nombreTournees})>
                moyennes,
          })>(
        future: _charger(ref),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger l\'historique.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final historique = snapshot.data!.historique;
          final moyennes = snapshot.data!.moyennes;
          if (historique.isEmpty) {
            return const Center(
              child: Text('Aucune tournée terminée pour le moment.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            children: [
              if (moyennes.isNotEmpty) ...[
                const Text(
                  'Vitesse moyenne par préparateur',
                  style: AppTypography.chipLabel,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                for (final m in moyennes)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimensions.spacingXs,
                    ),
                    child: _MoyenneRow(moyenne: m),
                  ),
                const SizedBox(height: AppDimensions.spacingLg),
                const Divider(),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
              for (final entry in historique) ...[
                _TourneeHistoriqueCard(
                  tour: entry.tour,
                  preparateurNom: entry.preparateurNom,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<
      ({
        List<({Tour tour, String preparateurNom})> historique,
        List<({String preparateurNom, Duration dureeMoyenne, int nombreTournees})>
            moyennes,
      })> _charger(WidgetRef ref) async {
    final service = ref.read(administrationServiceProvider);
    final historique = await service.historiqueAvecPreparateur();
    final moyennes = await service.moyennesVitesseParPreparateur();
    return (historique: historique, moyennes: moyennes);
  }
}

class _MoyenneRow extends StatelessWidget {
  const _MoyenneRow({required this.moyenne});

  final ({String preparateurNom, Duration dureeMoyenne, int nombreTournees}) moyenne;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(moyenne.preparateurNom, style: AppTypography.body),
        ),
        Text(
          '${_formatDuree(moyenne.dureeMoyenne)} en moyenne '
          '(${moyenne.nombreTournees} tournée${moyenne.nombreTournees > 1 ? 's' : ''})',
          style: AppTypography.secondaryLabel,
        ),
      ],
    );
  }
}

class _TourneeHistoriqueCard extends StatelessWidget {
  const _TourneeHistoriqueCard({required this.tour, required this.preparateurNom});

  final Tour tour;
  final String preparateurNom;

  @override
  Widget build(BuildContext context) {
    final duree = tour.dureeEcoulee;
    final produitsParMinute = duree != null && duree.inSeconds > 0
        ? tour.nombreTotalProduits / (duree.inSeconds / 60)
        : null;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: AppColors.success),
        title: Text(tour.numeroTournee),
        subtitle: Text(
          '$preparateurNom — ${tour.produitsTraites}/${tour.nombreTotalProduits} produits',
        ),
        trailing: duree == null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDuree(duree),
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (produitsParMinute != null)
                    Text(
                      '${produitsParMinute.toStringAsFixed(1)} produits/min',
                      style: AppTypography.secondaryLabel,
                    ),
                ],
              ),
      ),
    );
  }
}

String _formatDuree(Duration d) {
  final heures = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (heures > 0) return '${heures}h ${minutes.toString().padLeft(2, '0')}min';
  return '${d.inMinutes}min';
}
