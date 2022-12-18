import 'log.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
import 'recource_loader.dart';
import 'location_alias.dart';
import 'dart:math';

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
          ? await SimulateGps.next()
          : GPS(pos.latitude, pos.longitude);
      return Future<GPS>.value(gps);
    } catch (e, stk) {
      logFatal('GPS::gps', e, stk);
    }
    return Future<GPS>.value(GPS(0, 0));
  }
}

class _Gps {
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
  static int _nextStop = 3;

  static Future<GPS> next() async {
    _station ??= await station;
    if (--_nextStop <= 0) {
      _nextStop = Random().nextInt(10) + 5;
      Alias alias = await station;
      logInfo('SimulateGps::nextStop for $_nextStop ticks at ${alias.address}');
      // shuffle position a little
      return GPS(shake(alias.lat), shake(alias.lon));
    } else {
      _station?.lat = shake(_station?.lat ?? 0);
      _station?.lon = shake(_station?.lon ?? 0);
      return GPS(_station?.lat ?? 0, _station?.lon ?? 0);
    }
  }

  static double shake(double pos) {
    int direction = Random().nextBool() ? 1 : -1;
    pos = pos + Random().nextDouble() / 1000 * direction;
    return pos;
  }

  static Future<Alias> get station async {
    Alias st;
    try {
      List<Alias> stations = await LocationAlias.loadeAliasList();
      if (stations.isEmpty) throw ('loadedAliasList is empty');
      st = _station = stations[Random().nextInt(stations.length - 1)];
    } catch (e, str) {
      logWarn('SimulateGps', e, str);
      st = _station = Alias(0, 'undefined', _Gps.lat, _Gps.lon);
    }

    return Future<Alias>.value(st);
  }
}
