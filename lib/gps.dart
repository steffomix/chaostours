/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'dart:async';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

//import 'package:geolocator/geolocator.dart' show Position, Geolocator;
//
import 'package:chaostours/conf/globals.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';

class PendingGps extends GPS {
  PendingGps(super.lat, super.lon);

  /// creates gps trackPoint with timestamp
  String toSharedString() {
    return <String>[super.toString(), time.toIso8601String()].join(';');
  }

  /// inverse of GPS.toSharedString()
  ///
  /// "lat,lon;time.toIso8601String()"
  static PendingGps toSharedObject(String row) {
    List<String> parts = row.split(';');

    List<String> p = parts[0].split(',');

    double lat = double.parse(p[0]);
    double lon = double.parse(p[1]);

    PendingGps gps = PendingGps(lat, lon);
    gps.time = DateTime.parse(parts[1]);
    return gps;
  }
}

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
    try {
      if (!(await Permission.location.isGranted)) {
        await Permission.location.request();
      }
      bool cacheOutdated =
          lastGps?.time.add(Globals.cacheGpsTime).isBefore(DateTime.now()) ??
              true;

      if (cacheOutdated) {
        /// cache is outdated
        GPS gps = await _gps();
        lastGps = gps;
        return gps;
      } else {
        /// use cache
        return lastGps!;
      }
    } catch (e, stk) {
      logger.error('get GPS: $e', stk);
      return await _gps();
    }
  }

  static Future<GPS> _gps() async {
    geo.Position pos = await geo.Geolocator.getCurrentPosition();
    return GPS(pos.latitude, pos.longitude);
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

  static double distance(GPS g1, GPS g2) =>
      distanceBetween(g1.lat, g1.lon, g2.lat, g2.lon);

  // calc distance over multiple trackpoints in meters
  static double distanceOverTrackList(List<GPS> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS? gps;
    for (var track in tracklist) {
      if (gps != null) {
        dist += GPS.distance(gps, track);
      }
      gps = track;
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

  static Future<void> launchGoogleMaps(
      double lat, double lon, double lat1, double lon1) async {
    var url = 'https://www.google.com/maps/dir/?'
        'api=1&origin=$lat%2c$lon&destination=$lat1%2c$lon1&'
        'travelmode=driving';

    final intent = AndroidIntent(
        action: 'action_view',
        data: url,
        package: 'com.google.android.apps.maps');
    intent.launch();
  }
}
