import 'package:genesis_picking/features/courier/data/courier_request.dart';
import 'package:genesis_picking/features/courier/data/courier_request_remote_sink.dart';

/// Implémentation en mémoire de [CourierRequestRemoteSink], pour vérifier
/// dans les tests que [CourierService] transmet bien les demandes créées
/// ou mises à jour — même principe que les autres fakes de ce dossier.
class FakeCourierRequestRemoteSink implements CourierRequestRemoteSink {
  final List<CourierRequest> pushed = [];
  final List<String> deleted = [];

  @override
  Future<void> pushRequest(CourierRequest request) async {
    pushed.add(request);
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    deleted.add(requestId);
  }
}
