import 'package:flutter/material.dart';
import 'package:genesis_picking/core/widgets/buttons/primary_button.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Action principale d'une tournée, selon son état — composant
/// réutilisable partagé entre "Mes tournées" (variante compacte) et
/// "Détail d'une tournée" (variante pleine largeur, très grand bouton).
///
/// Centralise la seule règle qui compte ici : quel libellé et quelle
/// action proposer pour quel état. Ni la liste ni l'écran de détail
/// n'ont à connaître cette règle par eux-mêmes.
class TourActionButton extends StatelessWidget {
  const TourActionButton({
    required this.tour,
    required this.isLoading,
    required this.onDownload,
    required this.onStartOrResume,
    super.key,
    this.compact = false,
  });

  final Tour tour;
  final bool isLoading;
  final VoidCallback onDownload;
  final VoidCallback onStartOrResume;

  /// Version compacte (`TextButton`) pour une ligne de liste ; version
  /// pleine largeur et grande (`PrimaryButton`) sinon.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final (label, onPressed) = switch (tour.statut) {
      TourStatus.disponible => ('Télécharger', onDownload),
      TourStatus.telechargee => ('Commencer', onStartOrResume),
      TourStatus.enCours => ('Reprendre', onStartOrResume),
      TourStatus.terminee => (null, null),
    };

    if (label == null) {
      return const Text('Terminée');
    }

    if (compact) {
      return TextButton(onPressed: onPressed, child: Text(label));
    }
    return PrimaryButton(label: label, onPressed: onPressed);
  }
}
