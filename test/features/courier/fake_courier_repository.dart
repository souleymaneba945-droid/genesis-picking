import 'package:genesis_picking/features/courier/data/courier_repository.dart';
import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_status.dart';

/// Implémentation en mémoire de [CourierRepository], utilisée uniquement
/// par les tests unitaires — permet de tester [CourierService] sans
/// dépendre de Drift. Les données survivent tant que l'instance existe,
/// ce qui permet de simuler une "reprise après fermeture" en recréant un
/// [CourierService] pointant vers la même instance de ce dépôt.
class FakeCourierRepository implements CourierRepository {
  final Map<String, CourierRequest> _requests = {};
  int _sequence = 0;

  @override
  Future<CourierRequest> create({
    required String preparateurId,
    required String coursierId,
    required String tourId,
    required String productLineId,
    required int quantiteDemandee,
    required String emplacement,
    String? produitNom,
    String? produitDescription,
    String? produitImageUrl,
  }) async {
    _sequence++;
    final request = CourierRequest(
      id: 'req-$_sequence',
      preparateurId: preparateurId,
      coursierId: coursierId,
      tourId: tourId,
      productLineId: productLineId,
      quantiteDemandee: quantiteDemandee,
      emplacement: emplacement,
      dateCreation: DateTime.now(),
      etat: CourierRequestStatus.creee,
      produitNom: produitNom,
      produitDescription: produitDescription,
      produitImageUrl: produitImageUrl,
    );
    _requests[request.id] = request;
    return request;
  }

  @override
  Future<CourierRequest?> findById(String requestId) async => _requests[requestId];

  @override
  Future<List<CourierRequest>> listForCoursier(String coursierId) async {
    final list = _requests.values
        .where((r) => r.coursierId == coursierId)
        .toList()
      ..sort((a, b) => a.dateCreation.compareTo(b.dateCreation));
    return list;
  }

  @override
  Future<List<CourierRequest>> listForPreparateur(String preparateurId) async {
    final list = _requests.values
        .where((r) => r.preparateurId == preparateurId)
        .toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    return list;
  }

  @override
  Future<List<CourierRequest>> listAll() async {
    final list = _requests.values.toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    return list;
  }

  @override
  Future<int> countOpenRequestsFor(String coursierId) async {
    return _requests.values
        .where((r) => r.coursierId == coursierId && r.estOuverte)
        .length;
  }

  @override
  Future<void> updateStatus({
    required String requestId,
    required CourierRequestStatus etat,
    CourierRequestResult? resultat,
    DateTime? dateAcceptation,
    DateTime? dateTraitement,
    DateTime? dateCloture,
  }) async {
    final existing = _requests[requestId];
    if (existing == null) return;
    _requests[requestId] = existing.copyWith(
      etat: etat,
      resultat: resultat,
      dateAcceptation: dateAcceptation,
      dateTraitement: dateTraitement,
      dateCloture: dateCloture,
    );
  }

  @override
  Future<void> upsertFromRemote(CourierRequest request) async {
    _requests[request.id] = request;
  }

  @override
  Future<void> delete(String requestId) async {
    _requests.remove(requestId);
  }
}
