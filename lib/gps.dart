import 'dart:async';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:geolocator/geolocator.dart' as geo;

//import 'package:geolocator/geolocator.dart' show Position, Geolocator;
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';

class GPS {
  static Logger logger = Logger.logger<GPS>();

  static GPS? lastGps;
  static int _nextId = 0;
  final int _id = ++_nextId;
  int get id => _id;
  DateTime time = DateTime.now();
  double lat;
  double lon;

  GPS(this.lat, this.lon);

  static Future<GPS> gps() async {
    if (lastGps == null) {
      /// no cache present yet
      return await _gps();
    } else {
      var t = lastGps!.time;
      if (t.add(Globals.cacheGpsTime).isAfter(DateTime.now())) {
        /// cache is outdated
        return await _gps();
      } else {
        /// use cache
        return lastGps!;
      }
    }
  }

  static Future<GPS> _gps() async {
    geo.Position pos = await geo.Geolocator.getCurrentPosition();
    return lastGps ??= GPS(pos.latitude, pos.longitude);
  }

  @override
  String toString() {
    return '$lat,$lon';
  }

  /// inverse of GPS.toString()
  static GPS toObject(String row) {
    List<String> p = row.split(',');
    double lat = double.parse(p[0]);
    double lon = double.parse(p[1]);
    return GPS(lat, lon);
  }

  /// creates gps trackPoint with timestamp
  String toSharedString() {
    return <String>[toString(), time.toIso8601String()].join(';');
  }

  /// inverse of GPS.toSharedString()
  ///
  /// "time.toIso8601String();lat,lon"
  static GPS toSharedObject(String row) {
    List<String> p = row.split(';');
    GPS gps = GPS.toObject(p[0]);
    gps.time = DateTime.parse(p[1]);
    return gps;
  }

  static double distance(GPS g1, GPS g2) =>
      distanceBetween(g1.lat, g1.lon, g2.lat, g2.lon);

  // calc distance over multiple trackpoints in meters
  static double distanceoverTrackList(List<GPS> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS gps = tracklist[0];
    for (var i = 1; i < tracklist.length; i++) {
      dist += GPS.distance(gps, tracklist[i]);
      gps = tracklist[i];
    }
    return dist;
  }

  /// Calculates the distance between the supplied coordinates in meters.
  ///
  /// The distance between the coordinates is calculated using the Haversine
  /// formula (see https://en.wikipedia.org/wiki/Haversine_formula). The
  /// supplied coordinates [startLatitude], [startLongitude], [endLatitude] and
  /// [endLongitude] should be supplied in degrees.
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    var earthRadius = 6378137.0;
    var dLat = _toRadians(endLatitude - startLatitude);
    var dLon = _toRadians(endLongitude - startLongitude);

    var a = pow(sin(dLat / 2), 2) +
        pow(sin(dLon / 2), 2) *
            cos(_toRadians(startLatitude)) *
            cos(_toRadians(endLatitude));
    var c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// Calculates the initial bearing between two points
  ///
  /// The initial bearing will most of the time be different than the end
  /// bearing, see https://www.movable-type.co.uk/scripts/latlong.html#bearing.
  /// The supplied coordinates [startLatitude], [startLongitude], [endLatitude]
  /// and [endLongitude] should be supplied in degrees.
  static double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    var startLongitudeRadians = radians(startLongitude);
    var startLatitudeRadians = radians(startLatitude);
    var endLongitudeRadians = radians(endLongitude);
    var endLatitudeRadians = radians(endLatitude);

    var y = sin(endLongitudeRadians - startLongitudeRadians) *
        cos(endLatitudeRadians);
    var x = cos(startLatitudeRadians) * sin(endLatitudeRadians) -
        sin(startLatitudeRadians) *
            cos(endLatitudeRadians) *
            cos(endLongitudeRadians - startLongitudeRadians);

    return degrees(atan2(y, x));
  }
}
