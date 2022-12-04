import 'logger.dart';
import 'package:geolocator/geolocator.dart'
    show Position, LocationPermission, Geolocator;

class GPS {
  static int _nextId = 0;

  final int _id = ++GPS._nextId;
  double lat = 0;
  double lon = 0;
  bool _gpsOk = false;

  int get id => _id;
  bool get gpsOk => _gpsOk;

  /// calculate distance between two gps points in meters
  static double distance(GPS p1, GPS p2) {
    return Geolocator.distanceBetween(p1.lat, p1.lon, p2.lat, p2.lon);
  }

  // 52.3840, 9.7260
  static double _lat = 52.384;
  static double _lon = 9.726;
  static double move() {
    _lat += 0.0002;
    return _lat;
  }

  GPS() {
    lat = _lat;
    lon = _lon;
    _gpsOk = true;
  }

  _GPS() {
    try {
      lookupGPS().then((p) {
        lat = p.latitude;
        lon = p.longitude;
        _gpsOk = true;
      }).onError((e, stackTrace) {
        severe('gps failed: ${e.toString()}');
      });
    } catch (e) {
      severe('gps failed: ${e.toString()}');
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
