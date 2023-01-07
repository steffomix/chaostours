import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/events.dart';
import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/gps.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) {
    eventOnGps.fire(GPS(data.lat, data.lon));
    return Future<void>.value();
  }); //(data) async => Repo().update(data),
}

void main() async {
  // Thanks for: https://stackoverflow.com/a/69481863
  // add cert for https requests you can download here:
  // https://letsencrypt.org/certs/lets-encrypt-r3.pem
  WidgetsFlutterBinding.ensureInitialized();

  // set loglevel
  Logger.level = Level.info;

  // preload recources
  await RecourceLoader.preload();

  // instantiate TrackingCalendar singelton
  TrackingCalendar();

  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Globals.version = packageInfo.version;
  } catch (e) {
    logError(e);
  }

  await BackgroundLocationTrackerManager.initialize(
    backgroundCallback,
    config: const BackgroundLocationTrackerConfig(
      loggingEnabled: true,
      androidConfig: AndroidConfig(
        notificationIcon: 'explore',
        trackingInterval: Duration(seconds: 4),
        distanceFilterMeters: null,
      ),
      iOSConfig: IOSConfig(
        activityType: ActivityType.FITNESS,
        distanceFilterMeters: null,
        restartAfterKill: true,
      ),
    ),
  );

  // start gps tracking
  TrackPoint.startTracking();

  // start frontend
  runApp(Globals.app);
}
