import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/theme/app_dimensions.dart';
import 'package:genesis_picking/core/theme/app_typography.dart';
import 'package:genesis_picking/core/widgets/feedback/app_snackbar.dart';
import 'package:genesis_picking/features/picking/presentation/picking_screen.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_action_button.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_status_badge.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

/// Écran "Détail d'une tournée" — un écran, une décision : consulter
/// l'état d'une tournée avant de la commencer ou de la reprendre.
///
/// Aucun produit n'est affiché ici (voir Directive Module 4) : uniquement
/// les informations de la tournée elle-même. Le bouton d'action est très
/// grand (Directive production) et occupe seul le bas de l'écran.
class TourDetailScreen extends ConsumerStatefulWidget {
  const TourDetailScreen({required this.tour, super.key});

  final Tour tour;

  @override
  ConsumerState<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends ConsumerState<TourDetailScreen> {
  late Tour _tour;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tour = widget.tour;
  }

  Future<void> _download() async {
    setState(() => _isLoading = true);
    final result = await ref.read(tourServiceProvider).downloadTour(_tour.id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    result.when(
      success: (updated) {
        setState(() => _tour = updated);
        AppSnackbar.showSuccess(context, 'Tournée téléchargée.');
      },
      failure: (exception) =>
          AppSnackbar.showError(context, ErrorHandler.userMessageFor(exception)),
    );
  }

  void _startOrResume() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PickingScreen(tourId: _tour.id)))
        .then((_) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    final progression = _tour.nombreTotalProduits == 0
        ? 0.0
        : _tour.produitsTraites / _tour.nombreTotalProduits;

    return Scaffold(
      appBar: AppBar(title: Text(_tour.numeroTournee)),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_tour.numeroTournee, style: AppTypography.screenTitle),
                TourStatusChip(statut: _tour.statut),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            if (_tour.estTeleChargeeLocalement) ...[
              Text(
                '${_tour.produitsTraites}/${_tour.nombreTotalProduits} produits traités',
                style: AppTypography.secondaryLabel,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
                child: LinearProgressIndicator(
                  value: progression,
                  minHeight: 10,
                ),
              ),
            ] else
              const Text(
                'Cette tournée n\'a pas encore été téléchargée sur cet '
                'appareil.',
                style: AppTypography.secondaryLabel,
              ),
            const Spacer(),
            TourActionButton(
              tour: _tour,
              isLoading: _isLoading,
              onDownload: _download,
              onStartOrResume: _startOrResume,
            ),
          ],
        ),
      ),
    );
  }
}
