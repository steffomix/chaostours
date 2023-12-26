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

//import 'package:background_location_tracker/background_location_dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/database/cache_modules.dart';
import 'dart:math' as math;

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/location.dart';
import 'package:chaostours/calendar.dart';
//import 'package:chaostours/database.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';

import 'database/type_adapter.dart';

enum TrackingStatus {
  none(0),
  standing(1),
  moving(2);

  final int value;
  const TrackingStatus(this.value);

  /// used for ModelTrackpoint serialization only
  static TrackingStatus byValue(int id) {
    TrackingStatus status =
        TrackingStatus.values.firstWhere((status) => status.value == id);
    return status;
  }
}

class Tracker {
  final Logger logger = Logger.logger<Tracker>();

  static Tracker? _instance;
  Tracker._();
  factory Tracker() => _instance ??= Tracker._();

  List<GPS> gpsPoints = [];
  List<GPS> gpsSmoothPoints = [];
  List<GPS> gpsCalcPoints = [];

  /// initials
  TrackingStatus oldTrackingStatus = TrackingStatus.standing;
  TrackingStatus? trackingStatus;

  GPS? gpsLastStatusChange;

  GPS? gpsLastStatusStanding;
  GPS? gpsLastStatusMoving;

  Address? address;

  Map<String, dynamic> serializeState(GPS gps) {
    Map<String, dynamic> serialized = {
      DataChannelKey.gps.toString(): TypeAdapter.serializeGps(gps),
      DataChannelKey.gpsPoints.toString():
          TypeAdapter.serializeGpsList(gpsPoints),
      DataChannelKey.gpsSmoothPoints.toString():
          TypeAdapter.serializeGpsList(gpsSmoothPoints),
      DataChannelKey.gpsCalcPoints.toString():
          TypeAdapter.serializeGpsList(gpsCalcPoints),
      DataChannelKey.gpsLastStatusChange.toString(): gpsLastStatusChange == null
          ? null
          : TypeAdapter.serializeGps(gpsLastStatusChange!),
      DataChannelKey.gpsLastStatusMoving.toString(): gpsLastStatusMoving == null
          ? null
          : TypeAdapter.serializeGps(gpsLastStatusMoving!),
      DataChannelKey.gpsLastStatusStanding.toString():
          gpsLastStatusStanding == null
              ? null
              : TypeAdapter.serializeGps(gpsLastStatusStanding!),
      DataChannelKey.trackingStatus.toString():
          TypeAdapter.serializeTrackingStatus(trackingStatus!),
      DataChannelKey.lastAddress.toString(): address?.alias ?? '-',
      DataChannelKey.lastFullAddress.toString(): address?.description ?? '-',
    };
    return serialized;
  }

  Future<Map<String, dynamic>> track() async {
    /// create gpsPoint
    GPS gps = await GPS.gps();

    // make sure there are no old gps data
    if (trackingStatus == null) {
      gpsPoints = await Cache.backgroundGpsPoints.save<List<GPS>>([]);
    }

    trackingStatus ??= await Cache.backgroundTrackingStatus
        .save<TrackingStatus>(TrackingStatus.standing);
    gpsLastStatusMoving ??= await Cache.backgroundGpsStartMoving.save<GPS>(gps);
    gpsLastStatusStanding ??=
        await Cache.backgroundGpsStartStanding.save<GPS>(gps);
    gpsLastStatusChange ??=
        await Cache.backgroundGpsLastStatusChange.save<GPS>(gps);

    gps = await claculateGPSPoints(gps);

    /// collect gps related data
    Location gpsLocation = await Location.location(gps);

    /// remember old status
    TrackingStatus newTrackingStatus = oldTrackingStatus = await Cache
        .backgroundTrackingStatus
        .load<TrackingStatus>(TrackingStatus.standing);

    ///
    /// process trackpoint
    ///
    ///
    /// process user trigger
    TrackingStatus triggeredTrackingStatus = await Cache.trackingStatusTriggered
        .load<TrackingStatus>(TrackingStatus.none);

    if (triggeredTrackingStatus != TrackingStatus.none) {
      /// reset trigger
      await Cache.trackingStatusTriggered
          .save<TrackingStatus>(TrackingStatus.none);

      newTrackingStatus = (triggeredTrackingStatus == TrackingStatus.standing)
          ? await cacheNewStatusStanding(gps)
          : await cacheNewStatusMoving(gps);
    } else {
      /// check for standing
      if (oldTrackingStatus == TrackingStatus.standing) {
        /// start check with assumed true value
        bool checkStartedMoving = true;

        GPS gpsStandingStartet = await Cache.backgroundGpsStartStanding
            .load<GPS>(gpsCalcPoints.last);

        /// check if all calc points are below distance treshold
        for (var gps in gpsCalcPoints) {
          if (GPS.distance(gpsStandingStartet, gps) <= gpsLocation.radius) {
            // still standing
            checkStartedMoving = false;
            break;
          }
        }
        if (checkStartedMoving) {
          newTrackingStatus = await cacheNewStatusMoving(gps);
        }
      } else if (oldTrackingStatus == TrackingStatus.moving) {
        if (GPS.distanceOverTrackList(gpsCalcPoints) < gpsLocation.radius) {
          await cacheNewStatusStanding(gps);

          /// autocreate alias?
          if ((await Cache.appSettingStatusStandingRequireAlias
                  .load<bool>(true)) &&
              gpsLocation.aliasModels.isEmpty) {
            try {
              /// autocreate must be activated
              if (await Cache.appSettingAutocreateAlias.load<bool>(false)) {
                /// check if enough time has passed
                if ((await Cache.backgroundGpsStartMoving.load<GPS>(gps))
                    .time
                    .isBefore(gps.time.subtract(await Cache
                        .appSettingAutocreateAliasDuration
                        .load<Duration>(AppUserSetting(
                                Cache.appSettingAutocreateAliasDuration)
                            .defaultValue as Duration)))) {
                  gps = GPS.average(gpsCalcPoints);
                  gps.time = DateTime.now();
                  gpsLocation = await gpsLocation.autocreateAlias(gps);
                }
              }
            } catch (e, stk) {
              logger.error('autocreate alias: $e', stk);
            }
          }
        }
      }
    }

    /// if nothing has changed, nothing to do
    if (newTrackingStatus == oldTrackingStatus) {
      /// lookup address on every interval
      address = await Address(gps)
          .lookup(OsmLookupConditions.onBackgroundGps, saveToCache: true);

      ///
    } else {
      /// we started moving
      if (newTrackingStatus == TrackingStatus.moving) {
        logger.log('tracking status MOVING');

        await gpsLocation.executeStatusMoving();

        ///
      } else if (newTrackingStatus == TrackingStatus.standing) {
        logger.log('new tracking status STANDING');

        await gpsLocation.executeStatusStanding();
        logger.log('tracking status STANDING finished');
      }
    }

    return serializeState(gps);
  }

  Future<GPS> claculateGPSPoints(GPS gps) async {
    Duration autoCreateAliasDefault =
        AppUserSetting(Cache.appSettingAutocreateAliasDuration).defaultValue
            as Duration;

    Duration autoCreateAliasDuration = await Cache
        .appSettingAutocreateAliasDuration
        .load<Duration>(autoCreateAliasDefault);

    Duration trackpointInterval =
        await Cache.appSettingBackgroundTrackingInterval.load<Duration>(
            AppUserSetting(Cache.appSettingBackgroundTrackingInterval)
                .defaultValue as Duration);

    Duration timeRangeTreshold = await Cache.appSettingTimeRangeTreshold
        .load<Duration>(AppUserSetting(Cache.appSettingTimeRangeTreshold)
            .defaultValue as Duration);

    int maxGpsPoints = ((autoCreateAliasDuration.inSeconds == 0
                ? autoCreateAliasDefault.inSeconds
                : autoCreateAliasDuration.inSeconds) /
            trackpointInterval.inSeconds)
        .ceil();

    gpsPoints.insert(0, gps);

    if (gpsPoints.length != maxGpsPoints) {
      /// prefill gpsPoints
      while (gpsPoints.length <= maxGpsPoints) {
        var gpsFiller = GPS(gps.lat, gps.lon);
        gpsFiller.time = gpsPoints.last.time.add(trackpointInterval);
        gpsPoints.add(gpsFiller);
      }

      /// prune gpsPoints
      while (gpsPoints.length > maxGpsPoints) {
        gpsPoints.removeLast();
      }
    }

    /// filter gps points for trackpoint calculation
    gpsSmoothPoints = await calculateSmoothPoints(gpsPoints);

    /// extract calculation points from smoothed points
    gpsCalcPoints = gpsSmoothPoints
        .getRange(
            0,
            math.min(
                gpsSmoothPoints.length - 1,
                (timeRangeTreshold.inSeconds / trackpointInterval.inSeconds)
                    .ceil()))
        .toList();

    gps = gpsCalcPoints.first;

    /// all gps points calculated, save them
    await Cache.backgroundLastGps.save<GPS>(gps);
    gpsPoints = await Cache.backgroundGpsPoints.save<List<GPS>>(gpsPoints);
    gpsSmoothPoints =
        await Cache.backgroundGpsSmoothPoints.save<List<GPS>>(gpsSmoothPoints);
    gpsCalcPoints =
        await Cache.backgroundGpsCalcPoints.save<List<GPS>>(gpsCalcPoints);

    return gps;
  }

  Future<TrackingStatus> cacheNewStatusStanding(GPS gps) async {
    trackingStatus = await Cache.backgroundTrackingStatus
        .save<TrackingStatus>(TrackingStatus.standing);
    await Cache.backgroundGpsStartStanding.save<GPS>(gps);
    await Cache.backgroundGpsLastStatusChange.save<GPS>(gps);
    gpsLastStatusChange = gps;
    gpsLastStatusStanding = gps;
    return TrackingStatus.standing;
  }

  Future<TrackingStatus> cacheNewStatusMoving(GPS gps) async {
    trackingStatus = await Cache.backgroundTrackingStatus
        .save<TrackingStatus>(TrackingStatus.moving);
    await Cache.backgroundGpsStartMoving.save<GPS>(gps);
    await Cache.backgroundGpsLastStatusChange.save<GPS>(gps);
    gpsLastStatusChange = gps;
    gpsLastStatusMoving = gps;
    return TrackingStatus.moving;
  }

  Future<List<GPS>> calculateSmoothPoints(List<GPS> gpsPoints) async {
    List<GPS> smoothGpsPoints = [];
    int smoothCount = await Cache.appSettingGpsPointsSmoothCount.load<int>(
        AppUserSetting(Cache.appSettingGpsPointsSmoothCount).defaultValue
            as int);
    if (smoothCount < 2) {
      /// smoothing is disabled
      smoothGpsPoints.addAll(gpsPoints);
      return smoothGpsPoints;
    }

    if (gpsPoints.length <= smoothCount) {
      logger.warn('too few gpsPoints for $smoothCount smoothPoints. '
          'Use all gpsPoints as smoothPoints directly without smmothing effect');
      smoothGpsPoints.addAll(gpsPoints);
      return smoothGpsPoints;
    }
    int index = 0;
    int range = gpsPoints.length - smoothCount;
    while (index < range) {
      try {
        var averageGps = GPS
            .average(gpsPoints.getRange(index, index + smoothCount).toList());
        averageGps.time = gpsPoints[index].time;
        smoothGpsPoints.add(averageGps);
      } catch (e, stk) {
        logger.error('calculateSmoothPoints: $e', stk);
      }
      index++;
    }
    return smoothGpsPoints;
  }
}
