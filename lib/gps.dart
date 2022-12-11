import 'logger.dart';
import 'config.dart';
import 'dart:math' show Random;
import 'package:geolocator/geolocator.dart'
    show Position, LocationPermission, Geolocator;

class GpsLocation {
  double _lat = 0;
  double _lon = 0;
  bool _gpsOk = false;

  double get lat {
    if (!_gpsOk) throw ('gps lookup not ready');
    return AppConfig.debugMode ? _lat + _testLat : _lat;
  }

  double get lon {
    if (!_gpsOk) throw ('gps lookup not ready');
    return AppConfig.debugMode ? _lon + _testLon : _lon;
  }

  bool get gpsOk => _gpsOk;

  GpsLocation(this._lat, this._lon) {
    _gpsOk = true;
  }

  GpsLocation.pending() {
    if (AppConfig.debugMode) {
      Future.delayed(Duration(milliseconds: Random().nextInt(2000)), () {
        _lat = _testLat;
        _lon = _testLon;
        _gpsOk = true;
      });
    }
  }

  // 52.3840, 9.7260 hannover
  // 52.32741, 9.19255
  static double _testLat = 52.32741;
  static double _testLon = 9.19255;
  static void move() {
    _testLat += 0.0002;
    _testLon += 0.00015;
  }
}

class GPS {
  static int _nextId = 0;

  final int _id = ++GPS._nextId;

  GpsLocation _location = GpsLocation.pending();

  int get id => _id;
  double get lat => _location.lat;
  double get lon => _location.lon;
  bool get gpsOk => _location.gpsOk;

  /// calculate distance between two gps points in meters
  static double distance(GPS p1, GPS p2) {
    return Geolocator.distanceBetween(p1.lat, p1.lon, p2.lat, p2.lon);
  }

  GPS() {
    if (!AppConfig.debugMode) {
      try {
        lookupGPS().then((p) {
          _location = GpsLocation(p.latitude, p.longitude);
        }).onError((e, stackTrace) {
          severe('gps failed: ${e.toString()}');
        });
      } catch (e) {
        severe('gps failed: ${e.toString()}');
      }
    }
  }

  Future<Position> lookupGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }
}
