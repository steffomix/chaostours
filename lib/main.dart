import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/log.dart';
// import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/tracking.dart';
import 'trackpoint.dart';

// android native code

void main() async {
  // Thanks for: https://stackoverflow.com/a/69481863
  // add cert for https requests you can download here:
  // https://letsencrypt.org/certs/lets-encrypt-r3.pem
  WidgetsFlutterBinding.ensureInitialized();

  // set loglevel
  Logger.level = Level.info;

  // preload recources
  await RecourceLoader.preload();

  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Globals.version = packageInfo.version;
  } catch (e) {
    logError(e);
  }

  // init tracking processor
  TrackPoint();
  // start gps tracking
  TrackPoint.startTracking();
  await Tracking().initialize();

  // start frontend
  runApp(Globals.app);
}
