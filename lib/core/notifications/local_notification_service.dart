import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:genesis_picking/core/logging/app_logger.dart';

/// Notifications système (bannière + son), affichées tant que l'app
/// tourne — premier plan, ou arrière-plan Android tant que le processus
/// est vivant. Ne couvre PAS le cas app totalement fermée (voir le
/// commentaire de dépendance dans `pubspec.yaml` : ça demanderait Firebase
/// Cloud Messaging + un déclencheur serveur, donc le plan Blaze,
/// indisponible pour l'instant).
///
/// Enveloppe volontairement fine autour de `flutter_local_notifications` :
/// aucune règle métier ici (quand notifier, à propos de quoi) — ça reste
/// entièrement du ressort de l'appelant (voir
/// `CourierNotificationWatcher`, seul utilisateur actuel). Ce service ne
/// sait qu'afficher une notification.
///
/// Mobile uniquement (Android/iOS) : sur toute autre plateforme (ex.
/// `flutter run -d windows` en développement), [initialize] ne fait rien
/// et [show] devient un no-op silencieux — jamais de crash au démarrage
/// pour une fonctionnalité annexe.
class LocalNotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'courier_requests';
  static const _channelName = 'Demandes coursier';
  static const _channelDescription =
      "Alerte à la réception d'une nouvelle demande de produit introuvable";

  static bool get _plateformeSupportee =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialise le plugin, crée le canal Android et demande la permission
  /// d'affichage (Android 13+, iOS). Idempotent — sûr à appeler plusieurs
  /// fois (ex. reconnexions successives d'un même appareil).
  Future<void> initialize() async {
    if (_initialized || !_plateformeSupportee) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (error, stackTrace) {
      AppLogger.warning(
        "Impossible d'initialiser les notifications locales — le coursier "
        'ne recevra pas d\'alerte système pour les nouvelles demandes',
        tag: 'LocalNotificationService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Affiche une notification immédiate. `id` doit être stable pour une
  /// même demande — [CourierNotificationWatcher] utilise le hash de
  /// l'identifiant Firestore de la demande.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Échec de l\'affichage de la notification "$title"',
        tag: 'LocalNotificationService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
