import 'dart:isolate';

import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/log.dart';
// import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/shared.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/gps.dart';
import 'dart:async';

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

  Shared(SharedKeys.backgroundGps).observe(
      duration: const Duration(seconds: 1),
      fn: (String data) {
        List<String> geo = data.split(',');
        double lat = double.parse(geo[0]);
        double lon = double.parse(geo[1]);
        EventManager(EventKeys.onGps).fire(EventOnGps(GPS(lat, lon)));
      });
  EventManager(EventKeys.onGps).listen((Event event) {
    if (event is EventOnGps) {
      GPS gps = event.gps;
      TrackPoint.trackBackground(gps);
    }
  });

  // start frontend
  runApp(Globals.app);
}

class EventOnGps extends Event {
  final GPS gps;
  EventOnGps(this.gps);
}
