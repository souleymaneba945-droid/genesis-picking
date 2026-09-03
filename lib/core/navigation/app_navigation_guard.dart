import 'package:genesis_picking/core/navigation/app_routes.dart';
import 'package:genesis_picking/core/session/user_role.dart';

/// Logique de redirection de la navigation, extraite de `GoRouter` en
/// fonctions pures — testables sans `BuildContext` ni `GoRouterState`
/// (Directive production : "tests de navigation").
///
/// `app_router.dart` ne fait que déléguer ici ; aucun changement de
/// comportement, uniquement une meilleure testabilité.
class AppNavigationGuard {
  AppNavigationGuard._();

  static const Set<String> allHomeRoutes = {
    AppRoutes.homeAdministrateur,
    AppRoutes.homePreparateur,
    AppRoutes.homeCoursier,
  };

  static String homeRouteFor(UserRole role) {
    return switch (role) {
      UserRole.administrateur => AppRoutes.homeAdministrateur,
      UserRole.preparateur => AppRoutes.homePreparateur,
      UserRole.coursier => AppRoutes.homeCoursier,
    };
  }

  /// Vrai si [location] est l'accueil d'un rôle DIFFÉRENT de [role] —
  /// c'est ce contrôle qui empêche un utilisateur authentifié d'atteindre
  /// l'accueil d'un autre rôle (voir Module 9, audit sécurité).
  static bool isForeignRoleHome(String location, UserRole role) {
    return allHomeRoutes.contains(location) && location != homeRouteFor(role);
  }

  /// Décide où rediriger l'utilisateur, ou `null` si aucune redirection
  /// n'est nécessaire. Reproduit exactement la logique de
  /// `appRouterProvider.redirect`, dans une fonction pure.
  static String? resolveRedirect({
    required UserRole? role,
    required bool isGoingToLogin,
    required bool isSplash,
    required String matchedLocation,
  }) {
    if (isSplash) return null;

    if (role == null) {
      return isGoingToLogin ? null : AppRoutes.login;
    }

    if (isGoingToLogin) {
      return homeRouteFor(role);
    }

    if (isForeignRoleHome(matchedLocation, role)) {
      return homeRouteFor(role);
    }

    return null;
  }
}
