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
import 'dart:math' as math;
import 'package:chaostours/database/cache.dart';
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:android_intent_plus/android_intent.dart';

//
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/value_expired.dart';
import 'package:chaostours/logger.dart';

const earthRadius = 6378137.0;

/// <pre>
///         [N++lat]
/// [W--lon]        [E++lon]
///         [S--lat]
///
/// Latitude zero is at Equator
/// Longitude zero is at GB London, Gateway to London Campus, University of the West of Scotland (UWS),
/// </pre>
class GpsArea {
  final GPS north;
  final GPS east;
  final GPS south;
  final GPS west;

  /// North border
  double get northLatitudeBorder => north.lat;

  /// South border
  double get southLatitudeBorder => south.lat;

  /// West border
  double get westLongitudeBorder => west.lon;

  /// East border
  double get eastLongitudeBorder => east.lon;

  bool isInArea({
    double? lat,
    double? lon,
    GPS? gps,
  }) {
    lat ??= gps?.lat;
    lon ??= gps?.lon;
    if (lat == null || lon == null) {
      throw ('GpsArea::isInArea: provide rather a gps or lat and lon');
    }
    return (lat >= southLatitudeBorder &&
        lat <= northLatitudeBorder &&
        lon >= westLongitudeBorder &&
        lon <= eastLongitudeBorder);
  }

  factory GpsArea(
      {required double latitude,
      required double longitude,
      required int distanceInMeters}) {
    return _calculateArea(
        latitude: latitude,
        longitude: longitude,
        distanceInMeters: distanceInMeters);
  }

  GpsArea.byArea(
      {required this.north,
      required this.east,
      required this.south,
      required this.west});

  static _calculateArea(
      {required double latitude,
      required double longitude,
      required int distanceInMeters}) {
    /*
    credit to: @ssten https://stackoverflow.com/a/50506609/4823385


    
/// <pre>
///         [N++lat]
/// [W--lon]        [E++lon]
///         [S--lat]
///
      var earth = 6378.137,  //radius of the earth in kilometer
          pi = Math.PI,
          m = (1 / ((2 * pi / 360) * earth)) / 1000;  //1 meter in degree

      var new_latitude = latitude + (your_meters * m);
      For longitude do:

      var earth = 6378.137,  //radius of the earth in kilometer
          pi = Math.PI,
          cos = Math.cos,
          m = (1 / ((2 * pi / 360) * earth)) / 1000;  //1 meter in degree

      var new_longitude = longitude + (your_meters * m) / cos(latitude * (pi / 180));
      The variable your_meters can contain a positive or a negative value.
  */
    var earth = 6378.137, //radius of the earth in kilometer
        pi = math.pi;

    // new_latitude  = latitude  + (dy / r_earth) * (180 / pi);
    // new_longitude = longitude + (dx / r_earth) * (180 / pi) / cos(latitude * pi / 180);

    var north = latitude +
        (distanceInMeters / earth) * (180 / pi); //(distanceInMeters * m);
    var south = latitude - (distanceInMeters / earth) * (180 / pi);

    var west = longitude -
        (distanceInMeters / earth) * (180 / pi) / math.cos(latitude * pi / 180);
    var east = longitude +
        (distanceInMeters / earth) * (180 / pi) / math.cos(latitude * pi / 180);

    var gpsNorth = GPS(north, longitude);
    var gpsSouth = GPS(south, longitude);

    var gpsWest = GPS(latitude, west);
    var gpsEast = GPS(latitude, east);

    return GpsArea.byArea(
        north: gpsNorth, east: gpsEast, south: gpsSouth, west: gpsWest);
  }
}

class GPS {
  static Logger logger = Logger.logger<GPS>();

  static Duration defaultCacheDuration =
      AppUserSetting(Cache.appSettingCacheGpsTime).defaultValue as Duration;
  static ValueExpired _cachedGps =
      ValueExpired(value: null, expireAfter: ExpiredValue.immediately);
  DateTime time = DateTime.now();
  double lat;
  double lon;

  GPS(this.lat, this.lon);

  static Future<GPS> gps({useCache = false}) async {
    if (!useCache || _cachedGps.isExpired) {
      _cachedGps = ValueExpired(
          value: await _gps(), expireAfter: ExpiredValue.tenSeconds);
    }
    return await _cachedGps.value as GPS;
  }

  static Future<GPS> _gps() async {
    geo.Position pos = await geo.Geolocator.getCurrentPosition();
    return GPS(pos.latitude, pos.longitude);
  }

  @override
  String toString() {
    return '$lat,$lon;${time.toIso8601String()}';
  }

  /// inverse of GPS.toString()
  static GPS toObject(String row) {
    List<String> parts = row.split(';');
    var gpsParts = parts[0].split(',');
    double lat = double.parse(gpsParts[0]);
    double lon = double.parse(gpsParts[1]);
    var time = DateTime.parse(parts[1]);
    var gps = GPS(lat, lon);
    gps.time = time;
    return gps;
  }

  static GPS average(List<GPS> gpsList) {
    int count = 0;
    double lat = 0;
    double lon = 0;
    for (var gps in gpsList) {
      lat += gps.lat;
      lon += gps.lon;
      count++;
    }
    return GPS(lat / count, lon / count);
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
    // var earthRadius = 6378137.0;
    var dLat = toRadians(endLatitude - startLatitude);
    var dLon = toRadians(endLongitude - startLongitude);

    var a = math.pow(math.sin(dLat / 2), 2) +
        math.pow(math.sin(dLon / 2), 2) *
            math.cos(toRadians(startLatitude)) *
            math.cos(toRadians(endLatitude));
    var c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  static double toRadians(double degree) {
    return degree * math.pi / 180;
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

    var y = math.sin(endLongitudeRadians - startLongitudeRadians) *
        math.cos(endLatitudeRadians);
    var x = math.cos(startLatitudeRadians) * math.sin(endLatitudeRadians) -
        math.sin(startLatitudeRadians) *
            math.cos(endLatitudeRadians) *
            math.cos(endLongitudeRadians - startLongitudeRadians);

    return degrees(math.atan2(y, x));
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
