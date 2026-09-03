import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Contrat minimal de lecture de l'état réseau — permet à `SyncService`
/// (Module 6) de dépendre d'une interface plutôt que de [NetworkMonitor]
/// concret, pour être testé avec un faux entièrement contrôlable, sans
/// dépendre de `connectivity_plus` dans les tests.
abstract interface class ConnectivityState {
  bool get isOnline;
  Stream<bool> get onConnectivityChanged;
}

/// Détection de l'état réseau — UNE seule responsabilité : savoir si
/// l'appareil est actuellement en ligne, et notifier les changements.
///
/// Extrait au Module 6 pour que ce soit la seule classe du projet à
/// parler directement à `connectivity_plus`. [SyncManager] (Module 1) et
/// `SyncService` (Module 6) en dépendent tous les deux plutôt que de
/// dupliquer cette logique — voir Directive : "Chaque composant doit
/// avoir une responsabilité unique."
class NetworkMonitor implements ConnectivityState {
  NetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = false;
  @override
  bool get isOnline => _isOnline;

  /// Émet `true`/`false` uniquement lors d'un changement d'état (jamais
  /// deux fois la même valeur d'affilée), pour que les auditeurs puissent
  /// détecter sans ambiguïté une transition hors-ligne → en ligne.
  @override
  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  Future<void> start() async {
    final initial = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(initial);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = _hasConnection(results);
      if (nowOnline != _isOnline) {
        _isOnline = nowOnline;
        _onlineController.add(nowOnline);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}
