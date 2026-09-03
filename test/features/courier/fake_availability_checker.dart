import 'package:genesis_picking/features/courier/data/courier_availability_checker.dart';

/// Permet aux tests de simuler une coupure réseau ou son retour, sans
/// dépendre de `connectivity_plus` ni du [SyncManager] réel.
class FakeCourierAvailabilityChecker implements CourierAvailabilityChecker {
  FakeCourierAvailabilityChecker({bool isOnline = true}) : _isOnline = isOnline;

  bool _isOnline;

  @override
  bool get isOnline => _isOnline;

  void setOnline(bool value) => _isOnline = value;
}
