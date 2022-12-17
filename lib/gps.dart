import 'log.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
import 'recourceLoader.dart';
import 'locationAlias.dart';
import 'dart:math';

class GPS {
  static int _nextId = 0;
  final int _id = ++_nextId;
  int get id => _id;
  static double distance(GPS g1, GPS g2) =>
      Geolocator.distanceBetween(g1.lat, g1.lon, g2.lat, g2.lon);
  final double _lat;
  final double _lon;
  double get lat => _lat;
  double get lon => _lon;

  GPS(this._lat, this._lon) {
    logVerbose('GPS #$id at $_lat, $_lon');
  }

  static Future<GPS> gps() async {
    try {
      Position pos = await RecourceLoader.gps();
      GPS gps = AppConfig.debugMode
          ? await SimulateGps.next()
          : GPS(pos.latitude, pos.longitude);
      return Future<GPS>.value(gps);
    } catch (e, stk) {
      logFatal('GPS::gps', e, stk);
    }
    return Future<GPS>.value(GPS(0, 0));
  }
}

class _gps {
  // 52.3840, 9.7260 somewhere in hannover
  // 52.32741, 9.19255 somewhere in schaumburg
  static double _lat = 52.32741;
  static double _lon = 9.19255;
  static double v = 0.005;
  static double get _move => Random().nextInt(10) > 5 ? v : v * -1;
  static double get lat {
    _lat += _move;
    return _lat;
  }

  static double get lon {
    _lon += _move;
    return _lon;
  }
}

class SimulateGps {
  static Alias? _station;
  static List<Alias>? _stations;
  static int _nextStop = 0;

  static Future<GPS> next() async {
    _station ??= await station;
    if (--_nextStop <= 0) {
      _nextStop = Random().nextInt(10) + 5;
      Alias alias = await station;
      logInfo('SimulateGps::nextStop for $_nextStop ticks at ${alias.address}');
      return GPS(alias.lat, alias.lon);
    } else {
      return GPS(_station?.lat ?? 0, _station?.lon ?? 0);
    }
  }

  static Future<Alias> get station async {
    Alias st;
    try {
      List<Alias> stations = await LocationAlias.loadeAliasList();
      if (stations.isEmpty) throw ('loadedAliasList is empty');
      st = _station = stations[Random().nextInt(stations.length - 1)];
    } catch (e, str) {
      logWarn('SimulateGps', e, str);
      st = _station = Alias(0, 'undefined', _gps.lat, _gps.lon);
    }
    return Future<Alias>.value(st);
  }
}
