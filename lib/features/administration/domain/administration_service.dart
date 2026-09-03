import 'package:genesis_picking/core/errors/app_exception.dart';
import 'package:genesis_picking/core/errors/result.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/features/auth/data/user_repository.dart';
import 'package:genesis_picking/features/courier/data/courier_repository.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/tours/data/tour.dart';
import 'package:genesis_picking/features/tours/data/tour_repository.dart';
import 'package:genesis_picking/features/tours/data/tour_status.dart';

/// Service métier de l'Administration.
///
/// Ne fait qu'AGRÉGER et ORCHESTRER des lectures/actions déjà exposées
/// par les dépôts des autres modules (`TourRepository`, `CourierRepository`,
/// `UserRepository`) — aucune règle de picking, de collecte ou de
/// traitement coursier n'est reproduite ici. Les seules actions d'écriture
/// sont la réassignation d'une tournée et la gestion des comptes (déjà
/// livrée au Module 2, inchangée).
class AdministrationService {
  AdministrationService({
    required TourRepository tourRepository,
    required CourierRepository courierRepository,
    required UserRepository userRepository,
  })  : _tourRepository = tourRepository,
        _courierRepository = courierRepository,
        _userRepository = userRepository;

  final TourRepository _tourRepository;
  final CourierRepository _courierRepository;
  final UserRepository _userRepository;

  /// Vue d'ensemble (Cahier des charges, écran 4.13) : toutes les
  /// tournées non terminées, les plus récentes en premier.
  Future<List<Tour>> tourneesEnCours() async {
    final tours = await _tourRepository.listAll();
    final actives = tours.where((t) => t.statut != TourStatus.terminee).toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    return actives;
  }

  /// Historique (écran 3.6) : tournées terminées, les plus récentes en
  /// premier.
  Future<List<Tour>> historiqueTournees() async {
    final tours = await _tourRepository.listAll();
    final terminees = tours
        .where((t) => t.statut == TourStatus.terminee)
        .toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    return terminees;
  }

  /// Toutes les demandes coursier (écran 3.5, vue globale), les plus
  /// récentes en premier.
  Future<List<CourierRequest>> toutesLesDemandes() {
    return _courierRepository.listAll();
  }

  /// [historiqueTournees], enrichi du nom du préparateur qui a réalisé
  /// chaque tournée — pour l'écran "Historique" (analyse de vitesse), qui
  /// affiche la durée réelle de picking (voir `Tour.dureeEcoulee`) à côté
  /// de qui l'a faite, jamais un simple numéro isolé.
  Future<List<({Tour tour, String preparateurNom})>>
      historiqueAvecPreparateur() async {
    final tours = await historiqueTournees();
    if (tours.isEmpty) return const [];

    final users = await _userRepository.listAll();
    final nomParId = {for (final u in users) u.id: u.nomAffichage};

    return [
      for (final t in tours)
        (tour: t, preparateurNom: nomParId[t.preparateurId] ?? 'Préparateur'),
    ];
  }

  /// Durée moyenne de picking par préparateur — uniquement sur les
  /// tournées clôturées dont la durée est connue (voir
  /// `Tour.dureeEcoulee` : jamais calculée pour une tournée sans
  /// dateDebut/dateFin, par exemple créée avant l'introduction de cette
  /// mesure). Triée du préparateur le plus rapide en moyenne au plus
  /// lent.
  Future<List<({String preparateurNom, Duration dureeMoyenne, int nombreTournees})>>
      moyennesVitesseParPreparateur() async {
    final avecNom = await historiqueAvecPreparateur();

    final dureesParPreparateur = <String, List<Duration>>{};
    for (final entry in avecNom) {
      final duree = entry.tour.dureeEcoulee;
      if (duree == null) continue;
      dureesParPreparateur.putIfAbsent(entry.preparateurNom, () => []).add(duree);
    }

    final resultats = [
      for (final entry in dureesParPreparateur.entries)
        (
          preparateurNom: entry.key,
          dureeMoyenne: Duration(
            microseconds: entry.value
                    .map((d) => d.inMicroseconds)
                    .reduce((a, b) => a + b) ~/
                entry.value.length,
          ),
          nombreTournees: entry.value.length,
        ),
    ]..sort((a, b) => a.dureeMoyenne.compareTo(b.dureeMoyenne));

    return resultats;
  }

  /// Préparateurs actifs, pour le choix lors d'une réassignation.
  Future<List<({String id, String nom})>> preparateursActifs() async {
    final users = await _userRepository.listAll();
    return users
        .where((u) => u.role == UserRole.preparateur && u.actif)
        .map((u) => (id: u.id, nom: u.nomAffichage))
        .toList();
  }

  /// Réassigne une tournée à un autre préparateur.
  ///
  /// Refuse la réassignation d'une tournée déjà terminée : l'historique
  /// ne doit jamais être modifié après coup.
  Future<Result<void>> reassignerTournee({
    required String tourId,
    required String newPreparateurId,
  }) async {
    final tour = await _tourRepository.findById(tourId);
    if (tour == null) {
      return const Result.failure(ValidationException('Tournée introuvable.'));
    }
    if (tour.statut == TourStatus.terminee) {
      return const Result.failure(
        ValidationException(
          'Une tournée déjà terminée ne peut pas être réassignée.',
        ),
      );
    }

    await _tourRepository.reassignPreparateur(
      tourId: tourId,
      newPreparateurId: newPreparateurId,
    );
    return const Result.success(null);
  }
}
