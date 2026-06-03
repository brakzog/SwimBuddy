import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  // Demande la permission (Android 13+, iOS)
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    // iOS : permission demandée à l'init
    return true;
  }

  // Notif méduses
  static Future<void> showJellyfishAlert({
    required int count,
    required double km,
    required int hoursAgo,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'jellyfish_alerts',
      'Alertes méduses',
      channelDescription: 'Signalements de méduses à proximité',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      1,
      'Méduses signalées à proximité',
      '$count signalement(s) à ${km.toStringAsFixed(1)} km — il y a ${hoursAgo}h',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // Notif de rappel avant nage
  static Future<void> showSessionReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'session_reminders',
      'Rappels de session',
      channelDescription: 'Rappels pour démarrer une session',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    await _plugin.show(
      2,
      'C\'est l\'heure de nager !',
      'La mer vous attend. Conditions vérifiées.',
      const NotificationDetails(android: androidDetails),
    );
  }

  // Annule toutes les notifs
  static Future<void> cancelAll() => _plugin.cancelAll();
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
