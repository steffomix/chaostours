//import 'dart:async';
//import 'dart:math';
//import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/log.dart';
import 'package:googleapis/cloudsearch/v1.dart';

class Notifications {
  static Notifications? _instance;
  Notifications._() {
    eventOnGps.on<GPS>().listen(onGps);
  }
  factory Notifications() => _instance ??= Notifications._();
  //
  static int id = DateTime.now().millisecond;
  static FlutterLocalNotificationsPlugin? plugin;
  bool pluginInitialized = false;

  void onGps(GPS gps) {
    logInfo('Notification Event onGps: ${gps.lat}, ${gps.lon}');
  }

  final settings = const InitializationSettings(
    android: AndroidInitializationSettings('mipmap/ic_launcher'),
    iOS: IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  Future<void> initialize() async {
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
