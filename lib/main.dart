import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/app.dart';
import 'package:genesis_picking/core/config/app_config.dart';
import 'package:genesis_picking/core/config/environment.dart';
import 'package:genesis_picking/core/errors/error_handler.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';
import 'package:genesis_picking/core/widgets/app_restart.dart';
import 'package:genesis_picking/firebase_options.dart';
import 'package:pdfrx/pdfrx.dart';

/// Point d'entrée unique de GENESIS PICKING.
///
/// Ordre d'initialisation volontairement strict :
/// 1. Liaison du binding Flutter (nécessaire avant tout appel plateforme).
/// 2. Configuration globale (environnement).
/// 3. Capture globale des erreurs — avant toute autre initialisation
///    pouvant échouer, pour qu'aucune erreur de démarrage ne soit perdue.
/// 4. `pdfrx` (rendu des photos produit d'une picking list PDF, voir
///    `pdf_photo_extractor.dart`) — requis avant tout usage direct de son
///    API document (import Administrateur), en dehors d'un widget.
/// 5. Firebase — support de synchronisation réelle entre appareils (voir
///    `core/sync/firebase_sync_transport.dart`). Une erreur ici (pas de
///    réseau au premier lancement, par ex.) ne doit jamais empêcher
///    l'application de démarrer : elle reste pleinement utilisable
///    hors-ligne, seule la synchronisation restera indisponible tant que
///    Firebase n'aura pas pu s'initialiser à une prochaine tentative.
/// 6. Lancement de l'application dans un [ProviderScope] (Riverpod).
///
/// La base de données locale et le gestionnaire de synchronisation ne
/// sont volontairement PAS ouverts ici : ils le sont paresseusement via
/// leurs providers respectifs, au moment où l'écran de démarrage
/// ([SplashScreen]) en a besoin — voir `core/providers/core_providers.dart`.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.initialize(environment: EnvironmentConfig.dev);
  ErrorHandler.initializeGlobalCapture();
  pdfrxFlutterInitialize();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error, stackTrace) {
    AppLogger.error(
      'Échec de l\'initialisation Firebase — l\'appli reste utilisable '
      'hors-ligne, la synchronisation réelle sera indisponible',
      tag: 'main',
      error: error,
      stackTrace: stackTrace,
    );
  }

  AppLogger.info('Démarrage de GENESIS PICKING', tag: 'main');

  // AppRestart englobe le ProviderScope (pas l'inverse) : voir
  // `core/widgets/app_restart.dart` — c'est ce qui permet à
  // `AppRestart.restart()` de recréer tout l'état Riverpod, session
  // comprise, pour un vrai "redémarrage" (bouton Paramètres).
  runApp(
    AppRestart(
      builder: (context) => const ProviderScope(child: GenesisPickingApp()),
    ),
  );
}
