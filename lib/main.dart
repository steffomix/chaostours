import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/globals.dart';

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

  // start gps tracking
  TrackPoint.startTracking();

  // start frontend
  runApp(Globals.app);
}
