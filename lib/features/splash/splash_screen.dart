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
    await ref.read(databaseSeederProvider).seedIfNeeded();
    // Best-effort, jamais bloquant (voir UserPullSync) : récupère les
    // comptes créés sur d'autres appareils avant que l'utilisateur ne
    // tente de se connecter, sans jamais retarder le démarrage en cas de
    // coupure réseau.
    await ref.read(userPullSyncProvider).pullAll();
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
