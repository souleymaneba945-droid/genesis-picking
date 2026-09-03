import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';
import 'package:genesis_picking/features/tours/presentation/widgets/tour_action_button.dart';

Tour _tour(TourStatus statut) {
  return Tour(
    id: 't1',
    numeroTournee: 'T-2026-0001',
    preparateurId: 'prep-1',
    dateCreation: DateTime(2026, 1, 1),
    statut: statut,
    etatSynchronisation: TourSyncState.enAttenteSynchronisation,
    nombreTotalProduits: 5,
    produitsTraites: 2,
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Tour tour,
    required VoidCallback onDownload,
    required VoidCallback onStartOrResume,
    bool isLoading = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TourActionButton(
            tour: tour,
            isLoading: isLoading,
            onDownload: onDownload,
            onStartOrResume: onStartOrResume,
          ),
        ),
      ),
    );
  }

  testWidgets('affiche "Télécharger" et déclenche onDownload pour une tournée disponible', (
    tester,
  ) async {
    var downloadCalled = false;
    await pump(
      tester,
      tour: _tour(TourStatus.disponible),
      onDownload: () => downloadCalled = true,
      onStartOrResume: () {},
    );

    expect(find.text('Télécharger'), findsOneWidget);
    await tester.tap(find.text('Télécharger'));
    expect(downloadCalled, isTrue);
  });

  testWidgets('affiche "Commencer" pour une tournée téléchargée', (tester) async {
    await pump(
      tester,
      tour: _tour(TourStatus.telechargee),
      onDownload: () {},
      onStartOrResume: () {},
    );
    expect(find.text('Commencer'), findsOneWidget);
  });

  testWidgets('affiche "Reprendre" et déclenche onStartOrResume pour une tournée en cours', (
    tester,
  ) async {
    var resumeCalled = false;
    await pump(
      tester,
      tour: _tour(TourStatus.enCours),
      onDownload: () {},
      onStartOrResume: () => resumeCalled = true,
    );

    expect(find.text('Reprendre'), findsOneWidget);
    await tester.tap(find.text('Reprendre'));
    expect(resumeCalled, isTrue);
  });

  testWidgets('affiche "Terminée" sans action pour une tournée terminée', (tester) async {
    await pump(
      tester,
      tour: _tour(TourStatus.terminee),
      onDownload: () {},
      onStartOrResume: () {},
    );
    expect(find.text('Terminée'), findsOneWidget);
  });

  testWidgets('affiche un indicateur de chargement plutôt qu\'un bouton', (tester) async {
    await pump(
      tester,
      tour: _tour(TourStatus.disponible),
      onDownload: () {},
      onStartOrResume: () {},
      isLoading: true,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Télécharger'), findsNothing);
  });
}
