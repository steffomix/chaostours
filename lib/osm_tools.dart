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

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;

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

  Future<void> renderAlias(osm.MapController mapController) async {
    await mapController.removeAllCircle();

    GPS currentGps = await GPS.gps();
    mapController.drawCircle(osm.CircleOSM(
      key: "circle${++circleId}",
      centerPoint:
          osm.GeoPoint(latitude: currentGps.lat, longitude: currentGps.lon),
      radius: 10,
      color: const Color.fromARGB(255, 247, 2, 255),
      strokeWidth: 10,
    ));

    List<GPS> gpsPoints =
        await Cache.backgroundGpsPoints.loadCache<List<GPS>>([]);
    if (gpsPoints.isEmpty) {
      return;
    }
    List<GPS> gpsSmoothPoints =
        await Cache.backgroundGpsSmoothPoints.loadCache<List<GPS>>([]);
    List<GPS> gpsCalcPoints =
        await Cache.backgroundGpsCalcPoints.loadCache<List<GPS>>([]);
    GPS lastStatusStanding =
        await Cache.backgroundGpsStartStanding.loadCache(gpsPoints.last);

    for (var alias in await ModelAlias.selsectActivated()) {
      try {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint:
              osm.GeoPoint(latitude: alias.gps.lat, longitude: alias.gps.lon),
          radius: alias.radius.toDouble(),
          color: const Color.fromARGB(72, 0, 0, 0),
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
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 2,
          color: AppColors.rawGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in gpsSmoothPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 3,
          color: AppColors.smoothedGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in gpsCalcPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 4,
          color: AppColors.calcGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }

      if (gpsPoints.isNotEmpty) {
        GPS gps = lastStatusStanding;
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
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
