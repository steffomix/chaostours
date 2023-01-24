import 'dart:async';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/logger.dart';

class GPS {
  static Logger logger = Logger.logger<GPS>();
  static int _nextId = 0;
  final int _id = ++_nextId;
  int get id => _id;
  static double distance(GPS g1, GPS g2) =>
      Geolocator.distanceBetween(g1.lat, g1.lon, g2.lat, g2.lon);
  double lat;
  double lon;

  GPS(this.lat, this.lon);

  static Future<GPS> gps() async {
    Position pos;
    try {
      pos = await AppLoader.gps();
      GPS gps = GPS(pos.latitude, pos.longitude);
      logger.verbose('GPS #${gps.id} at $gps');
      return gps;
    } catch (e, stk) {
      logger.fatal('GPS lookup failed: $e', stk);
      logger.log('create spare GPS(0,0)');
    }
    return GPS(0, 0);
  }

  @override
  String toString() {
    return '$lat,$lon';
  }

  static GPS toObject(String row) {
    List<String> p = row.split(',');
    double lat = double.parse(p[0]);
    double lon = double.parse(p[1]);
    return GPS(lat, lon);
  }
}
