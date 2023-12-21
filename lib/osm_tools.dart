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

import 'package:chaostours/channel/data_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_colors.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/gps.dart';

class OsmTools {
  static final Logger logger = Logger.logger<OsmTools>();

  //static final bridge = DataBridge();
  static int circleId = 0;

  String get key {
    var k = 'circle${++circleId}';
    keys.add(k);
    return k;
  }

  String rectKey = '';

  List<String> keys = [];

  int maxRange = 30;

  List<GPS> getRange(List<GPS> source) {
    if (source.length > maxRange) {
      return source.getRange(0, maxRange).toList();
    }
    return source;
  }

  Future<void> renderAlias(MapController controller) async {
    DataChannel channel = DataChannel();

    if (channel.gpsPoints.isEmpty) {
      return;
    }
    GeoPoint geoPoint = await controller.centerMap;
    GPS currentGps = channel.gps ?? GPS(geoPoint.latitude, geoPoint.longitude);
    List<GPS> gpsPoints = getRange(channel.gpsPoints);
    List<GPS> gpsSmoothPoints = getRange(channel.gpsSmoothPoints);
    List<GPS> gpsCalcPoints = getRange(channel.gpsCalcPoints);
    GPS? lastStatusStanding = channel.gpsLastStatusStanding;
    while (keys.isNotEmpty) {
      controller.removeCircle(keys.removeLast());
    }

    controller.drawCircle(CircleOSM(
      key: key,
      centerPoint:
          GeoPoint(latitude: currentGps.lat, longitude: currentGps.lon),
      radius: 10,
      color: const Color.fromARGB(255, 247, 2, 255),
      strokeWidth: 10,
    ));

    for (var alias in await ModelAlias.byArea(
        gps: GPS(geoPoint.latitude, geoPoint.longitude), area: 1000 * 50)) {
      try {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint:
              GeoPoint(latitude: alias.gps.lat, longitude: alias.gps.lon),
          radius: alias.radius.toDouble(),
          color: alias.visibility.color,
          strokeWidth: 10,
        ));
      } catch (e, stk) {
        logger.error(e.toString(), stk);
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    /// draw gps points
    try {
      for (var gps in gpsPoints) {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint: GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 2,
          color: AppColors.rawGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in gpsSmoothPoints) {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint: GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 3,
          color: AppColors.smoothedGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in gpsCalcPoints) {
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint: GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 4,
          color: AppColors.calcGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }

      if (lastStatusStanding != null) {
        GPS gps = lastStatusStanding;
        controller.drawCircle(CircleOSM(
          key: key,
          centerPoint: GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 5,
          color: AppColors.lastTrackingStatusWithAliasDot.color,
          strokeWidth: 10,
        ));
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }
}
