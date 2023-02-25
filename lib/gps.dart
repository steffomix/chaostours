import 'dart:async';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
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
  DateTime? _time;
  DateTime get time => _time ??= DateTime.now();
  double lat;
  double lon;

  GPS(this.lat, this.lon);

  static Future<GPS> gps() async {
    /// use cache?

    var t = DateTime.now();
    if (lastGps != null &&
        lastGps!.time.add(Globals.cacheGpsTime).isBefore(t)) {
      return lastGps!;
    }

    try {
      var pos = await AppLoader.gps();
      var gps = GPS(pos.latitude, pos.longitude);
      gps._time = DateTime.now();
      logger.verbose('GPS #${gps.id} at $gps');
      lastGps = gps;
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
    gps._time = DateTime.parse(p[1]);
    return gps;
  }

  static double distance(GPS g1, GPS g2) =>
      Geolocator.distanceBetween(g1.lat, g1.lon, g2.lat, g2.lon);

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
}
