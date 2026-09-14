import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RouteNotifications {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> prepare() async {
    if (!_initialized) {
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_route'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    }
    final granted = Platform.isAndroid
        ? await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()!
              .requestNotificationsPermission()
        : await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()!
              .requestPermissions(alert: true, sound: true, badge: false);
    if (granted != true) {
      throw StateError(
        'Allow notifications in phone settings before starting off-route alerts.',
      );
    }
  }

  Future<void> show(String title, String message) => plugin.show(
    4102,
    title,
    message,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'camino_off_route',
        'Off-route alerts',
        channelDescription: 'Warnings during a walking session you start',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
  );
  Future<void> clear() async {
    if (_initialized) await plugin.cancel(4102);
  }
}
