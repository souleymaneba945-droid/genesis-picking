import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/navigation/app_navigation_guard.dart';
import 'package:genesis_picking/core/navigation/app_routes.dart';
import 'package:genesis_picking/core/providers/core_providers.dart';
import 'package:genesis_picking/features/administration/presentation/admin_shell.dart';
import 'package:genesis_picking/features/auth/presentation/login_screen.dart';
import 'package:genesis_picking/features/courier/presentation/coursier_shell.dart';
import 'package:genesis_picking/features/splash/splash_screen.dart';
import 'package:genesis_picking/features/tours/presentation/preparateur_shell.dart';
import 'package:go_router/go_router.dart';

/// Pont entre [sessionProvider] (Riverpod) et `GoRouter`, qui ne sait
/// réévaluer `redirect` qu'en réaction à un `Listenable` classique.
///
/// Sans ce pont, une connexion ou une déconnexion réussie change bien
/// l'état de session en mémoire, mais aucune navigation n'est jamais
/// redéclenchée : l'utilisateur reste bloqué sur l'écran de connexion (ou
/// sur l'accueil, à la déconnexion) malgré une session valide/close, car
/// `redirect` ne se relance que sur un événement de navigation explicite.
class _SessionRouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Configuration unique de la navigation de l'application.
///
/// Les trois rôles ont chacun leur véritable écran d'accueil
/// (AdminDashboardScreen, MyToursScreen, CourierHomeScreen). Toute la
/// décision de redirection est déléguée à [AppNavigationGuard], testée
/// indépendamment de `GoRouter`.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRouterRefresh();
  ref.listen(sessionProvider, (_, __) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      return AppNavigationGuard.resolveRedirect(
        role: session?.role,
        isGoingToLogin: state.matchedLocation == AppRoutes.login,
        isSplash: state.matchedLocation == AppRoutes.splash,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeAdministrateur,
        builder: (context, state) => const AdminShell(),
      ),
      GoRoute(
        path: AppRoutes.homePreparateur,
        builder: (context, state) => const PreparateurShell(),
      ),
      GoRoute(
        path: AppRoutes.homeCoursier,
        builder: (context, state) => const CoursierShell(),
      ),
    ],
  );
});
