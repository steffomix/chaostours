import 'logger.dart';
import 'config.dart';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
import 'recourceLoader.dart';

class GPS {
  static Function distance = Geolocator.distanceBetween;

  // 52.3840, 9.7260 hannover
  // 52.32741, 9.19255
  static double _testLat = 52.32741;
  static double _testLon = 9.19255;
  static void move() {
    _testLat += 0.0002;
    _testLon += 0.00015;
  }

  final double _lat;
  final double _lon;
  double get lat {
    return AppConfig.debugMode ? _testLat : _lat;
  }

  double get lon {
    return AppConfig.debugMode ? _testLon : _lon;
  }

  GPS(this._lat, this._lon);

  static Future<GPS> gps() async {
    Position pos = await RecourceLoader.gps();
    GPS gps = GPS(pos.latitude, pos.longitude);
    return Future<GPS>.value(gps);
  }
}
