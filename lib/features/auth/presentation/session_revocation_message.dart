import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Message transitoire affiché une seule fois par l'écran de connexion,
/// quand une session vient d'être fermée automatiquement suite à une
/// révocation à distance (Module 5 v2, Rubrique 3 — voir
/// `AccountRevocationWatcher`).
///
/// [consume] lit ET efface le message en un seul geste, pour qu'il ne
/// s'affiche jamais deux fois (ex. après un hot-reload, ou une seconde
/// visite de l'écran de connexion).
class SessionRevocationMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String message) => state = message;

  String? consume() {
    final message = state;
    state = null;
    return message;
  }
}

final sessionRevocationMessageProvider =
    NotifierProvider<SessionRevocationMessageNotifier, String?>(
  SessionRevocationMessageNotifier.new,
);
