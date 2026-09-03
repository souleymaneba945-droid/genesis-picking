import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/core/navigation/app_navigation_guard.dart';
import 'package:genesis_picking/core/navigation/app_routes.dart';
import 'package:genesis_picking/core/session/user_role.dart';

void main() {
  group('AppNavigationGuard.homeRouteFor', () {
    test('associe chaque rôle à son propre accueil', () {
      expect(
        AppNavigationGuard.homeRouteFor(UserRole.administrateur),
        AppRoutes.homeAdministrateur,
      );
      expect(
        AppNavigationGuard.homeRouteFor(UserRole.preparateur),
        AppRoutes.homePreparateur,
      );
      expect(
        AppNavigationGuard.homeRouteFor(UserRole.coursier),
        AppRoutes.homeCoursier,
      );
    });
  });

  group('AppNavigationGuard.isForeignRoleHome — sécurité par rôle', () {
    test('un préparateur sur l\'accueil admin est détecté comme étranger', () {
      expect(
        AppNavigationGuard.isForeignRoleHome(
          AppRoutes.homeAdministrateur,
          UserRole.preparateur,
        ),
        isTrue,
      );
    });

    test('un préparateur sur son propre accueil n\'est jamais étranger', () {
      expect(
        AppNavigationGuard.isForeignRoleHome(
          AppRoutes.homePreparateur,
          UserRole.preparateur,
        ),
        isFalse,
      );
    });

    test('une route qui n\'est l\'accueil d\'aucun rôle n\'est jamais étrangère', () {
      expect(
        AppNavigationGuard.isForeignRoleHome('/autre-chose', UserRole.coursier),
        isFalse,
      );
    });
  });

  group('AppNavigationGuard.resolveRedirect — parcours complet', () {
    test('l\'écran splash n\'est jamais redirigé', () {
      final redirect = AppNavigationGuard.resolveRedirect(
        role: null,
        isGoingToLogin: false,
        isSplash: true,
        matchedLocation: AppRoutes.splash,
      );
      expect(redirect, isNull);
    });

    test('sans session, tout accès hors connexion redirige vers la connexion', () {
      final redirect = AppNavigationGuard.resolveRedirect(
        role: null,
        isGoingToLogin: false,
        isSplash: false,
        matchedLocation: AppRoutes.homePreparateur,
      );
      expect(redirect, AppRoutes.login);
    });

    test('sans session, l\'écran de connexion lui-même n\'est pas redirigé', () {
      final redirect = AppNavigationGuard.resolveRedirect(
        role: null,
        isGoingToLogin: true,
        isSplash: false,
        matchedLocation: AppRoutes.login,
      );
      expect(redirect, isNull);
    });

    test('avec session, tenter la connexion redirige vers son propre accueil', () {
      final redirect = AppNavigationGuard.resolveRedirect(
        role: UserRole.coursier,
        isGoingToLogin: true,
        isSplash: false,
        matchedLocation: AppRoutes.login,
      );
      expect(redirect, AppRoutes.homeCoursier);
    });

    test('avec session, son propre accueil est toujours autorisé', () {
      final redirect = AppNavigationGuard.resolveRedirect(
        role: UserRole.administrateur,
        isGoingToLogin: false,
        isSplash: false,
        matchedLocation: AppRoutes.homeAdministrateur,
      );
      expect(redirect, isNull);
    });

    test('avec session, l\'accueil d\'un autre rôle redirige vers le sien (sécurité)', () {
      final redirect = AppNavigationGuard.resolveRedirect(
        role: UserRole.preparateur,
        isGoingToLogin: false,
        isSplash: false,
        matchedLocation: AppRoutes.homeAdministrateur,
      );
      expect(redirect, AppRoutes.homePreparateur);
    });

    test('avec session, un écran qui n\'est l\'accueil de personne reste accessible', () {
      final redirect = AppNavigationGuard.resolveRedirect(
        role: UserRole.coursier,
        isGoingToLogin: false,
        isSplash: false,
        matchedLocation: '/n-importe-quel-sous-ecran',
      );
      expect(redirect, isNull);
    });
  });
}
