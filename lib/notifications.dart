import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
import 'package:chaostours/log.dart';

class Notifications {
  static Notifications? _instance;
  Notifications._() {
    _initialize();
  }
  factory Notifications() => _instance ??= Notifications._();
  //
  static int id = DateTime.now().millisecond;
  static FlutterLocalNotificationsPlugin? plugin;
  bool pluginInitialized = false;

  final settings = const InitializationSettings(
    android: AndroidInitializationSettings('mipmap/ic_launcher'),
    iOS: IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  Future<void> _initialize() async {
    if (pluginInitialized) return;
    plugin ??= FlutterLocalNotificationsPlugin();
    pluginInitialized = await plugin!.initialize(
          settings,
          onSelectNotification: onSelectNotification,
        ) ??
        false;
  }

  Future<void> onSelectNotification(String? data) async {
    data ??= '-no Data-';
    logInfo('onSelectNotification Data: $data');
  }

  Future<void> send(String title, String text, {String data = ''}) {
    FlutterLocalNotificationsPlugin().show(
      id,
      title,
      text,
      const NotificationDetails(
        android: AndroidNotificationDetails(
            'Notification Informations', 'Notification'),
        iOS: IOSNotificationDetails(),
      ),
    );
    return Future<void>.value();
  }
}
