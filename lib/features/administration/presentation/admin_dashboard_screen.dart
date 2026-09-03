import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/administration/administration_providers.dart';
import 'package:genesis_picking/features/import/presentation/import_tour_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Onglet "Tournées" de l'Administrateur (Refonte UI) — tournées non
/// terminées, avec réassignation, plus l'accès à l'import (Cahier des
/// charges, écran 4.13). Les demandes coursier (vue globale) et
/// l'historique sont dans leurs propres onglets ("Suivi"), pour respecter
/// le principe "un écran, une décision".
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late Future<List<Tour>> _toursFuture;

  @override
  void initState() {
    super.initState();
    _toursFuture = ref.read(administrationServiceProvider).tourneesEnCours();
  }

  void _refresh() {
    setState(() {
      _toursFuture = ref.read(administrationServiceProvider).tourneesEnCours();
    });
  }

  Future<void> _openReassignDialog(Tour tour) async {
    final preparateurs = await ref
        .read(administrationServiceProvider)
        .preparateursActifs();
    if (!mounted) return;

    if (preparateurs.isEmpty) {
      AppSnackbar.showInfo(context, 'Aucun préparateur actif disponible.');
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Réassigner ${tour.numeroTournee}'),
        children: [
          for (final preparateur in preparateurs)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(preparateur.id),
              child: Text(preparateur.nom),
            ),
        ],
      ),
    );

    if (selected == null || !mounted) return;

    final result = await ref
        .read(administrationServiceProvider)
        .reassignerTournee(tourId: tour.id, newPreparateurId: selected);

    if (!mounted) return;
    result.when(
      success: (_) {
        AppSnackbar.showSuccess(context, 'Tournée réassignée.');
        _refresh();
      },
      failure: (exception) =>
          AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        // Tag explicite : ce FAB et celui de l'onglet "Utilisateurs" sont
        // montés simultanément (IndexedStack garde tous les onglets vivants
        // pour préserver leur état) — sans tag distinct, ils partagent le
        // tag Hero implicite par défaut et Flutter refuse de peindre les
        // deux (voir "multiple heroes had the same tag" en debug).
        heroTag: 'admin-tournees-fab',
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (_) => const ImportTourScreen()),
              )
              .then((_) => _refresh());
        },
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Importer'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _toursFuture;
        },
        child: FutureBuilder<List<Tour>>(
          future: _toursFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Impossible de charger les tournées.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tours = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
                AppDimensions.spacingLg,
                AppDimensions.spacingXl * 2,
              ),
              children: [
                const Text('Tournées', style: AppTypography.screenTitle),
                const SizedBox(height: AppDimensions.spacingLg),
                if (tours.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spacingXl),
                    child: Center(child: Text('Aucune tournée en cours.')),
                  )
                else
                  for (final tour in tours) ...[
                    _TourCard(
                      tour: tour,
                      onReassign: () => _openReassignDialog(tour),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({required this.tour, required this.onReassign});

  final Tour tour;
  final VoidCallback onReassign;

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
                    tour.numeroTournee,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_statusLabel(tour.statut)} · '
                    '${tour.produitsTraites}/${tour.nombreTotalProduits} produits',
                    style: AppTypography.secondaryLabel,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onReassign, child: const Text('Réassigner')),
          ],
        ),
      ),
    );
  }

  String _statusLabel(TourStatus statut) {
    return switch (statut) {
      TourStatus.disponible => 'Disponible',
      TourStatus.telechargee => 'Téléchargée',
      TourStatus.enCours => 'En cours',
      TourStatus.terminee => 'Terminée',
    };
  }
}
