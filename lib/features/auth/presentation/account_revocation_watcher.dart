import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/auth/data/user_account.dart';
import 'package:genesis_picking/features/auth/presentation/session_revocation_message.dart';

/// Ferme automatiquement la session en cours si le compte correspondant a
/// été désactivé par un administrateur ENTRE-TEMPS, dès que l'appareil
/// retrouve le réseau (Module 5 v2, Rubrique 3 — révocation à distance).
///
/// `setActive(actif: false)` (déjà en place, voir `UserManagementScreen`)
/// bloque déjà toute NOUVELLE connexion (`AuthService.login` vérifie
/// `account.actif`) — mais un appareil déjà connecté gardait l'accès
/// indéfiniment jusqu'ici : `SessionManager.restoreSession()` ne revérifie
/// jamais le statut du compte après coup. Ce watcher comble cet écart,
/// sans changer ni `SessionManager` ni `AuthService` : il se contente de
/// fermer la session existante
/// (`ref.read(sessionProvider.notifier).close()`), exactement comme le
/// ferait l'utilisateur lui-même via "Se déconnecter" — tout le reste
/// (redirection vers `/login`) suit déjà automatiquement, sans
/// `BuildContext`, via `app_router.dart` (`_SessionRouterRefresh` écoute
/// déjà `sessionProvider`).
///
/// Même famille que `CourierNotificationWatcher` : activé une seule fois
/// à la racine de l'app (`app.dart`), pour rester actif quel que soit
/// l'écran affiché.
///
/// LIMITE ASSUMÉE (voir `MODULE_5_V2.md`, Rubrique 3) : sans réseau,
/// aucune révocation à distance n'est possible — l'appareil doit
/// contacter le serveur pour l'apprendre. C'est la meilleure garantie
/// possible pour une app volontairement hors-ligne, jamais un vrai
/// verrou immédiat.
class AccountRevocationWatcher extends Notifier<void> {
  @override
  void build() {
    final session = ref.watch(sessionProvider);
    if (session == null) return;

    final monitor = ref.watch(networkMonitorProvider);
    final sub = monitor.onConnectivityChanged.listen((isOnline) {
      if (isOnline) _verifierStatutCompte(session.userId);
    });
    ref.onDispose(sub.cancel);
  }

  Future<void> _verifierStatutCompte(String userId) async {
    // Best-effort, jamais bloquant — même principe que `UserPullSync`
    // lui-même : un échec réseau ici laisse simplement la session active
    // telle quelle, à retenter à la prochaine reconnexion.
    await ref.read(userPullSyncProvider).pullAll();

    // La session a pu changer entre-temps (déconnexion manuelle pendant
    // l'attente ci-dessus) — ne jamais agir sur une session qui n'est
    // plus la bonne.
    final sessionActuelle = ref.read(sessionProvider);
    if (sessionActuelle == null || sessionActuelle.userId != userId) return;

    final comptes = await ref.read(userRepositoryProvider).listAll();
    UserAccount? compte;
    for (final c in comptes) {
      if (c.id == userId) {
        compte = c;
        break;
      }
    }
    if (!shouldRevokeSession(compte)) return;

    ref.read(sessionRevocationMessageProvider.notifier).set(
      'Ce compte a été désactivé par un administrateur.',
    );
    await ref.read(sessionProvider.notifier).close();
  }
}

final accountRevocationWatcherProvider =
    NotifierProvider<AccountRevocationWatcher, void>(
  AccountRevocationWatcher.new,
);

/// Vrai si la session du compte pull juste après un `pullAll()` doit être
/// fermée — extrait en fonction pure (aucune dépendance à Riverpod) pour
/// rester testable directement, sans avoir à construire tout un
/// `ProviderContainer`. `null` (compte disparu du serveur, cas
/// extrêmement rare) n'est JAMAIS traité comme une révocation — seul un
/// `actif == false` explicite l'est.
bool shouldRevokeSession(UserAccount? compte) {
  return compte != null && !compte.actif;
}
