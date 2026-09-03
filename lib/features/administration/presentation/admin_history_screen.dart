import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';

/// Écran Historique (Cahier des charges, écran 3.6) : tournées
/// terminées, consultables mais non modifiables (voir
/// `AdministrationService.reassignerTournee`, qui refuse explicitement
/// toute réassignation d'une tournée déjà terminée).
class AdminHistoryScreen extends ConsumerWidget {
  const AdminHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: FutureBuilder<List<Tour>>(
        future: ref.read(administrationServiceProvider).historiqueTournees(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger l\'historique.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tours = snapshot.data!;
          if (tours.isEmpty) {
            return const Center(
              child: Text('Aucune tournée terminée pour le moment.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            itemCount: tours.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDimensions.spacingSm),
            itemBuilder: (context, index) {
              final tour = tours[index];
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                  ),
                  title: Text(tour.numeroTournee),
                  subtitle: Text(
                    '${tour.produitsTraites}/${tour.nombreTotalProduits} produits traités',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
