import 'dart:async';
import 'log.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
import 'recource_loader.dart';
import 'package:chaostours/model_alias.dart';
import 'events.dart';

class GPS {
  static int _nextId = 0;
  final int _id = ++_nextId;
  int get id => _id;
  static double distance(GPS g1, GPS g2) =>
      Geolocator.distanceBetween(g1.lat, g1.lon, g2.lat, g2.lon);
  double lat;
  double lon;

  GPS(this.lat, this.lon) {
    logVerbose('GPS #$id at $lat, $lon');
  }

  static Future<GPS> gps() async {
    try {
      Position pos = await RecourceLoader.gps();
      GPS gps = AppConfig.debugMode
          ? SimulateGps.next()
          : GPS(pos.latitude, pos.longitude);
      return Future<GPS>.value(gps);
    } catch (e, stk) {
      logFatal('GPS::gps', e, stk);
    }
    return Future<GPS>.value(GPS(0, 0));
  }
}

var x = SimulateGps();

class SimulateGps {
  static double lat = 52.32741;
  static double lon = 9.19255;
  static double slow = 0.0001;
  double fast = 0.0001;
  static StreamSubscription<Tapped>? _listener;

  static StreamSubscription<Tapped> addListener() {
    var x = eventBusTapBottomNavBarIcon.on<Tapped>().listen((Tapped tapped) {
      switch (tapped.id) {
        case 0:
          lat += slow;
          break;
        case 1:
          ModelAlias alias = ModelAlias.random;
          lat = alias.lat;
          lon = alias.lon;
          break;
        case 2:
          lat -= slow;
          break;
        default:
          break;
      }
    });
    return x;
  }

  static GPS next() {
    _listener ??= addListener();
    SimulateGps();
    return GPS(lat, lon);
  }
}
