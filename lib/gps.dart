import 'log.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
import 'recourceLoader.dart';

class GPS {
  static double distance(GPS g1, GPS g2) =>
      Geolocator.distanceBetween(g1.lat, g1.lon, g2.lat, g2.lon);
  static void move() => _gps.move();
  final double _lat;
  final double _lon;
  double get lat => _lat;
  double get lon => _lon;

  GPS(this._lat, this._lon) {
    logVerbose('GPS $_lat, $_lon');
  }

  static Future<GPS> gps() async {
    try {
      Position pos = await RecourceLoader.gps();
      GPS gps = AppConfig.debugMode
          ? GPS(_gps.lat, _gps.lon)
          : GPS(pos.latitude, pos.longitude);
      return Future<GPS>.value(gps);
    } catch (e, stk) {
      logFatal('GPS::gps', e, stk);
    }
    return Future<GPS>.value(GPS(0, 0));
  }
}

class _gps {
// 52.3840, 9.7260 hannover
  // 52.32741, 9.19255
  static double lat = 52.32741;
  static double lon = 9.19255;
  static void move() {
    // 52.317736	9.206135
    lat = 52.317736;
    lon = 9.206135;
    /*
    _testLat += 0.0002;
    _testLon += 0.00015;
    */
  }
}
