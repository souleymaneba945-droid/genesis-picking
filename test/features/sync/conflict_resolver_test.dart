import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';
import 'package:genesis_picking/features/sync/domain/conflict_resolver.dart';

void main() {
  final resolver = ConflictResolver();

  group('resolveProgressiveState — deux mises à jour du même produit', () {
    test('conserve l\'état local si au moins aussi avancé', () {
      final resolution = resolver.resolveProgressiveState<String>(
        local: 'collecte',
        remote: 'aRecuperer',
        rangDansLeFlux: (s) => s == 'aRecuperer' ? 0 : 1,
      );
      expect(resolution.retained, 'collecte');
    });

    test('retient l\'état distant s\'il est plus avancé', () {
      final resolution = resolver.resolveProgressiveState<String>(
        local: 'aRecuperer',
        remote: 'collecte',
        rangDansLeFlux: (s) => s == 'aRecuperer' ? 0 : 1,
      );
      expect(resolution.retained, 'collecte');
    });

    test('un état déjà confirmé n\'est jamais régressé', () {
      final resolution = resolver.resolveProgressiveState<int>(
        local: 3, // ex. "Terminée"
        remote: 1, // ex. "En cours", reçu en retard
        rangDansLeFlux: (v) => v,
      );
      expect(resolution.retained, 3);
    });
  });

  group('resolveTourDeletionConflict — suppression d\'une tournée déjà modifiée', () {
    test('refuse la suppression si des modifications locales sont en attente', () {
      final resolution = resolver.resolveTourDeletionConflict(
        hasUnsyncedLocalChanges: true,
      );
      expect(resolution.retained, isFalse); // ne pas supprimer
    });

    test('accepte la suppression sans modification locale en attente', () {
      final resolution = resolver.resolveTourDeletionConflict(
        hasUnsyncedLocalChanges: false,
      );
      expect(resolution.retained, isTrue);
    });
  });

  group('resolveCourierResponseConflict — réponse coursier concurrente', () {
    test('retient la première réponse donnée dans le temps', () {
      final resolution = resolver.resolveCourierResponseConflict(
        first: CourierRequestResult.retrouve,
        firstAt: DateTime(2026, 1, 1, 10),
        second: CourierRequestResult.nonRetrouve,
        secondAt: DateTime(2026, 1, 1, 10, 5),
      );
      expect(resolution.retained, CourierRequestResult.retrouve);
    });

    test('fonctionne quel que soit l\'ordre de passage des paramètres', () {
      final resolution = resolver.resolveCourierResponseConflict(
        first: CourierRequestResult.nonRetrouve,
        firstAt: DateTime(2026, 1, 1, 10, 5),
        second: CourierRequestResult.retrouve,
        secondAt: DateTime(2026, 1, 1, 10),
      );
      expect(resolution.retained, CourierRequestResult.retrouve);
    });
  });

  group('resolveLastWriteWins', () {
    test('retient la valeur la plus récente', () {
      final resolution = resolver.resolveLastWriteWins<int>(
        local: 3,
        localTimestamp: DateTime(2026, 1, 1, 10),
        remote: 5,
        remoteTimestamp: DateTime(2026, 1, 1, 11),
      );
      expect(resolution.retained, 5);
    });

    test('conserve la valeur locale en cas d\'égalité stricte', () {
      final date = DateTime(2026, 1, 1, 10);
      final resolution = resolver.resolveLastWriteWins<int>(
        local: 3,
        localTimestamp: date,
        remote: 5,
        remoteTimestamp: date,
      );
      expect(resolution.retained, 3);
    });
  });
}
