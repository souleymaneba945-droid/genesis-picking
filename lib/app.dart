import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/core/l10n/app_localizations.dart';
import 'package:genesis_picking/core/navigation/app_router.dart';
import 'package:genesis_picking/core/theme/app_theme.dart';
import 'package:genesis_picking/features/courier/presentation/courier_notification_watcher.dart';

/// Widget racine de GENESIS PICKING.
///
/// Point unique de déclaration du thème, de la navigation et de
/// l'internationalisation. Aucun autre fichier ne doit construire de
/// second `MaterialApp`.
class GenesisPickingApp extends ConsumerWidget {
  const GenesisPickingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Actif tant que l'app existe (racine, jamais démontée) — c'est ce qui
    // permet à une notification de nouvelle demande coursier de se
    // déclencher même par-dessus un écran de détail, pas seulement depuis
    // `CoursierShell`. Voir `CourierNotificationWatcher`.
    ref.watch(courierNotificationWatcherProvider);

    return MaterialApp.router(
      title: 'GENESIS PICKING',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
