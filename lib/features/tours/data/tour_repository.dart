import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_remote_source.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Contrat abstrait du stockage local des tournées.
///
/// [TourService] ne dépend que de cette interface, jamais directement de
/// Drift — même principe que [UserRepository] au Module 2. Permet une
/// implémentation en mémoire pour les tests (voir `test/features/tours/`).
abstract interface class TourRepository {
  /// Tournées connues localement pour ce préparateur, quel que soit leur
  /// état (disponible, téléchargée, en cours, terminée).
  Future<List<Tour>> listForPreparateur(String preparateurId);

  /// Toutes les tournées, tous préparateurs confondus (Module 8 —
  /// Administration). Ajouté de façon strictement additive : aucune
  /// méthode existante n'est modifiée, les Modules 3 et 4 ne l'utilisent
  /// jamais.
  Future<List<Tour>> listAll();

  Future<Tour?> findById(String tourId);

  /// Enregistre l'existence d'une tournée "Disponible" (métadonnées
  /// seules, avant tout téléchargement) — n'écrase jamais une tournée
  /// déjà téléchargée localement si elle est appelée à nouveau avec le
  /// même identifiant (protection contre les doublons, Processus 2).
  Future<void> registerAvailableTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
  });

  /// Enregistre le contenu complet d'une tournée téléchargée (tournée +
  /// lignes produits) de façon atomique : soit tout est écrit, soit rien
  /// ne l'est — condition nécessaire à une reprise fiable après coupure
  /// réseau (Processus 2, Directive Module 3).
  ///
  /// Idempotent : si la tournée est déjà téléchargée localement, ne
  /// duplique rien et renvoie la tournée existante telle quelle.
  Future<Tour> saveDownloadedTour({
    required String tourId,
    required String numeroTournee,
    required String preparateurId,
    required List<TourProductPayload> produits,
  });

  Future<int> countProductLines(String tourId);

  /// [dateDebut]/[dateFin], si fournies, sont enregistrées avec le
  /// changement de statut — voir `TourService.startOrResume` (premier
  /// démarrage) et `TourService.completeTour` (clôture). N'écrase jamais
  /// une valeur déjà enregistrée avec `null` : un appelant qui ne les
  /// fournit pas laisse les valeurs existantes intactes.
  Future<void> updateStatus({
    required String tourId,
    required TourStatus statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  });

  /// Persiste le nombre de produits ayant un état final (Module 4).
  ///
  /// Ajouté de façon strictement additive au Module 4 : ne modifie ni ne
  /// retire aucune méthode existante, n'impacte donc pas le Module 3.
  Future<void> updateProgress({
    required String tourId,
    required int produitsTraites,
  });

  /// Réassigne une tournée à un autre préparateur (Module 8 —
  /// Administration). Ajouté de façon strictement additive.
  Future<void> reassignPreparateur({
    required String tourId,
    required String newPreparateurId,
  });

  Future<void> markSynchronized(String tourId);

  /// Supprime définitivement une tournée (métadonnées, lignes produits, et
  /// les états de collecte associés) — pour corriger un import erroné.
  /// N'affecte jamais les demandes coursier déjà envoyées pour ses
  /// produits : elles portent leur propre instantané (nom/description/
  /// photo, voir `CourierRequestsTable`) et restent valables même après
  /// coup, conformément au principe "l'historique du coursier n'est
  /// jamais réécrit par ailleurs".
  Future<void> delete(String tourId);
}
