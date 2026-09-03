import 'dart:async';

import 'package:genesis_picking/core/sync/network_monitor.dart';

/// Implémentation entièrement contrôlable de [ConnectivityState], pour
/// simuler des coupures et retours réseau dans les tests sans dépendre de
/// `connectivity_plus`.
class FakeConnectivityState implements ConnectivityState {
  FakeConnectivityState({bool isOnline = true}) : _isOnline = isOnline;

  bool _isOnline;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void setOnline(bool value) {
    if (value == _isOnline) return;
    _isOnline = value;
    _controller.add(value);
  }

  void dispose() => _controller.close();
}
