import 'package:permission_handler/permission_handler.dart';
import 'package:chaostours/log.dart';

class Permissions {
  static Permissions? _instance;
  Permissions._();
  factory Permissions() => _instance ??= Permissions._();

  Future<void> requestNotificationPermission() async {
    final result = await Permission.notification.request();
    if (result == PermissionStatus.granted) {
      logInfo('Notification Permission GRANTED'); // ignore: avoid_print
    } else {
      logInfo('Notification Permission NOT GRANTED'); // ignore: avoid_print
    }
  }

  Future<void> requestLocationPermission() async {
    final result = await Permission.locationAlways.request();
    if (result == PermissionStatus.granted) {
      print('Location Permission GRANTED'); // ignore: avoid_print
    } else {
      print('Location Permission NOT GRANTED'); // ignore: avoid_print
    }
  }
}
/*
  static Notification? _instance;
  Notification._() {
    eventOnGps.on<GPS>().listen(onGps);
  }
  factory Notification() => _instance ??= Notification._();
  */




/*
import 'dart:async';
import 'dart:math';
import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/gps.dart';

class Repo {
  static Repo? _instance;
  Repo._();
  factory Repo() => _instance ??= Repo._();

  Future<void> update(BackgroundLocationUpdateData data) async {
    final text = 'Location Update: Lat: ${data.lat} Lon: ${data.lon}';
    print(text); // ignore: avoid_print
    sendNotification(text);
    await LocationDao().saveLocation(data);
  }
}

class LocationDao {
  static const _locationsKey = 'background_updated_locations';
  static const _locationSeparator = '-/-/-/';

  static LocationDao? _instance;

  LocationDao._();

  factory LocationDao() => _instance ??= LocationDao._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> saveLocation(BackgroundLocationUpdateData data) async {
    final locations = await getLocations();
    locations.add(
        '${DateTime.now().toIso8601String()}       ${data.lat},${data.lon}');
    await (await prefs)
        .setString(_locationsKey, locations.join(_locationSeparator));
  }

  Future<List<String>> getLocations() async {
    final prefs = await this.prefs;
    await prefs.reload();
    final locationsString = prefs.getString(_locationsKey);
    if (locationsString == null) return [];
    return locationsString.split(_locationSeparator);
  }

  Future<void> clear() async => (await prefs).clear();
}

void sendNotification(String text) {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('app_icon'),
    iOS: IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );
  FlutterLocalNotificationsPlugin().initialize(
    settings,
    onSelectNotification: (data) async {
      print('ON CLICK $data'); // ignore: avoid_print
    },
  );
  FlutterLocalNotificationsPlugin().show(
    Random().nextInt(9999),
    'Title',
    text,
    const NotificationDetails(
      android: AndroidNotificationDetails('test_notification', 'Test'),
      iOS: IOSNotificationDetails(),
    ),
  );
}
*/
