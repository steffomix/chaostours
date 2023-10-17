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
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/gps.dart';

class OsmTools {
  static final Logger logger = Logger.logger<OsmTools>();

  static final bridge = DataBridge();
  static int circleId = 0;

  Future<void> renderAlias(osm.MapController mapController) async {
    await mapController.removeAllCircle();

    for (var alias in await ModelAlias.select(limit: 1000)) {
      try {
        ModelAliasGroup? group = await ModelAliasGroup.byId(alias.groupId);
        if (!(group?.isActive ?? false)) {
          mapController.drawCircle(osm.CircleOSM(
            key: "circle${++circleId}",
            centerPoint:
                osm.GeoPoint(latitude: alias.gps.lat, longitude: alias.gps.lon),
            radius: alias.radius.toDouble(),
            color: const Color.fromARGB(72, 0, 0, 0),
            strokeWidth: 10,
          ));
        } else {
          mapController.drawCircle(osm.CircleOSM(
            key: "circle${++circleId}",
            centerPoint:
                osm.GeoPoint(latitude: alias.gps.lat, longitude: alias.gps.lon),
            radius: alias.radius.toDouble(),
            color: AppColors.aliasStatusColor(
                group?.visibility ?? AliasVisibility.restricted),
            strokeWidth: 10,
          ));
        }
      } catch (e, stk) {
        logger.error(e.toString(), stk);
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    /// draw gps points
    try {
      for (var gps in bridge.gpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 2,
          color: AppColors.rawGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in bridge.smoothGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 3,
          color: AppColors.smoothedGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      for (var gps in bridge.calcGpsPoints) {
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 4,
          color: AppColors.calcGpsTrackingDot.color,
          strokeWidth: 10,
        ));
      }
      if (bridge.gpsPoints.isNotEmpty) {
        GPS gps = bridge.trackPointGpsStartStanding ?? bridge.gpsPoints.last;
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 5,
          color: AppColors.lastTrackingStatusWithAliasDot.color,
          strokeWidth: 10,
        ));
      }
      if (bridge.trackPointGpsStartStanding != null &&
          bridge.trackingStatus == TrackingStatus.standing &&
          bridge.trackPointAliasIdList.isEmpty) {
        GPS gps = bridge.trackPointGpsStartStanding!;
        mapController.drawCircle(osm.CircleOSM(
          key: "circle${++circleId}",
          centerPoint: osm.GeoPoint(latitude: gps.lat, longitude: gps.lon),
          radius: 5,
          color: AppColors.lastTrackingStatusWithoutAliasDot.color,
          strokeWidth: 10,
        ));
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }
}
