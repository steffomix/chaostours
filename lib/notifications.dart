import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
import 'package:chaostours/logger.dart';

class Notifications {
  static Logger logger = Logger.logger<Notifications>();
  static Notifications? _instance;
  Notifications._() {
    _initialize();
  }
  factory Notifications() => _instance ??= Notifications._();
  //
  static int id = DateTime.now().millisecond;
  static FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool pluginInitialized = false;

  Future<void> _initialize() async {
    logger.log('initialize');
    if (pluginInitialized) return;
    pluginInitialized = (await plugin.initialize(
            const InitializationSettings(
                android: AndroidInitializationSettings('mipmap/ic_launcher')),
            onDidReceiveNotificationResponse: (NotificationResponse res) {
          ///
        }, onDidReceiveBackgroundNotificationResponse:
                (NotificationResponse res) {
          ///
        })) ??
        false;
  }

  Future<void> onSelectNotification(String? data) async {
    data ??= '-no Data-';
    logger.log('onSelectNotification Data: $data');
  }

  Future<void> send(String title, String text, {String data = ''}) async {
    logger.log('Send title: $title; text:text; data: data');
    FlutterLocalNotificationsPlugin().show(
      id,
      title,
      text,
      const NotificationDetails(
          android: AndroidNotificationDetails(
              'Notification Informations', 'Notification')),
    );
  }
}
