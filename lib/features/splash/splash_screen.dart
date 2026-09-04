import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/navigation/app_routes.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/core/session/user_role.dart';
import 'package:genesis_picking/core/theme/app_colors.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/sync/sync_providers.dart';
import 'package:go_router/go_router.dart';

/// Écran de démarrage.
///
/// Rôle strictement technique : tenter une restauration de session locale
/// (Processus 1 — "session locale valide") avant de rediriger vers la
/// connexion ou vers l'accueil du rôle concerné. Ne doit jamais rester
/// affiché plus de quelques instants (voir Document UX/UI : "chaque écran
/// doit s'afficher instantanément").
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(localDatabaseProvider).open();
    // Récupère d'abord les comptes déjà connus du serveur — AVANT de
    // semer un admin par défaut — pour qu'une nouvelle installation sur
    // un appareil qui a déjà accès au réseau récupère le VRAI compte
    // admin existant plutôt que d'en créer un nouveau. Sans cet ordre :
    // `seedIfNeeded()` créait un compte local ET LE POUSSAIT
    // IMMÉDIATEMENT vers Firestore (voir `SyncingUserRepository.create`)
    // avant que cet appel n'ait eu la moindre chance de dire qu'un admin
    // existait déjà ailleurs — chaque nouvelle installation ajoutait
    // ainsi un doublon "admin" de plus sur le serveur, jamais nettoyé
    // (13 comptes "admin" distincts accumulés en 4 jours avant que ce
    // bug ne soit identifié). Best-effort, jamais bloquant : un échec
    // réseau ici laisse simplement la base locale vide, et
    // `seedIfNeeded()` juste en dessous crée alors le tout premier
    // compte admin comme avant.
    await ref.read(userPullSyncProvider).pullAll();
    await ref.read(databaseSeederProvider).seedIfNeeded();
    await ref.read(sessionProvider.notifier).restore();
    await ref.read(syncManagerProvider).initialize();
    ref.read(syncServiceProvider).startAutoSync();

    if (!mounted) return;

    final session = ref.read(sessionProvider);
    if (session == null) {
      context.go(AppRoutes.login);
      return;
    }

    // `SessionManager.restoreSession` ne connaît que l'identifiant
    // technique (voir son commentaire) — on relit maintenant le vrai nom
    // depuis le compte local (déjà à jour, `userPullSyncProvider` vient
    // de tourner juste au-dessus) pour ne plus jamais afficher un id brut
    // à l'écran Profil après une simple réouverture de l'appli.
    final comptes = await ref.read(userRepositoryProvider).listAll();
    for (final compte in comptes) {
      if (compte.id == session.userId) {
        ref
            .read(sessionProvider.notifier)
            .refreshDisplayName(session.userId, compte.nomAffichage);
        break;
      }
    }

    if (!mounted) return;

    final route = switch (session.role) {
      UserRole.administrateur => AppRoutes.homeAdministrateur,
      UserRole.preparateur => AppRoutes.homePreparateur,
      UserRole.coursier => AppRoutes.homeCoursier,
    };
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
