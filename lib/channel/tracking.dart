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

import 'dart:math' as math;

///
//import 'package:background_location_tracker/background_location_dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/gps_location.dart';
import 'package:chaostours/database/type_adapter.dart';

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

  int tick = 0;

  DateTime upTimeStart = DateTime.now();

  List<GPS> gpsPoints = [];
  List<GPS> gpsSmoothPoints = [];
  List<GPS> gpsCalcPoints = [];

  Duration statusDuration = Duration.zero;

  TrackingStatus triggeredTrackingStatus = TrackingStatus.none;

  /// initials
  TrackingStatus oldTrackingStatus = TrackingStatus.standing;
  TrackingStatus? trackingStatus;

  GPS? gpsLastStatusChange;

  GPS? gpsLastStatusStanding;
  GPS? gpsLastStatusMoving;

  Address? address;

  Future<Map<String, dynamic>> serializeState(GPS gps) async {
    statusDuration = (gpsLastStatusChange?.time ?? DateTime.now())
        .difference(DateTime.now())
        .abs();
    Map<String, dynamic> serialized = {
      DataChannelKey.tick.toString(): tick.toString(),
      DataChannelKey.upTime.toString(): upTimeStart.toIso8601String(),
      DataChannelKey.gps.toString(): TypeAdapter.serializeGps(gps),
      DataChannelKey.gpsPoints.toString():
          TypeAdapter.serializeGpsList(gpsPoints),
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
      DataChannelKey.lastAddress.toString(): address?.address ?? '',
      DataChannelKey.lastFullAddress.toString(): address?.addressDetails ?? '',
      DataChannelKey.statusDuration.toString():
          TypeAdapter.serializeDuration(statusDuration)
    };
    address = null;
    //await Cache.backgroundGpsPoints.save<List<GPS>>(gpsPoints);
    return serialized;
  }

  Future<Map<String, dynamic>> track() async {
    tick++;

    /// create gpsPoint
    ///
    GPS gps = await GPS.gps();

    // load old gps points
    if (trackingStatus == null) {
      //gpsPoints = await Cache.backgroundGpsPoints.load<List<GPS>>([]);
    }

    trackingStatus ??= TrackingStatus.standing;
    gpsLastStatusMoving ??= gps;
    gpsLastStatusStanding ??= gps;
    gpsLastStatusChange ??= gps;

    //gps = await
    await claculateGPSPoints(gps);

    /// collect gps related data
    GpsLocation gpsLocation = await GpsLocation.location(gps);

    /// remember old status
    TrackingStatus newTrackingStatus = oldTrackingStatus;

    ///
    /// process trackpoint
    ///
    ///
    /// process user trigger

    if (triggeredTrackingStatus != TrackingStatus.none) {
      if (triggeredTrackingStatus == TrackingStatus.moving) {
        // status changed by user
        newTrackingStatus = setStatusMoving(gps);
      } else if (triggeredTrackingStatus == TrackingStatus.standing) {
        /* gpsPoints.clear();
        gps = await claculateGPSPoints(gps); */
        // status changed by user
        newTrackingStatus = setStatusStanding(gps);
      }

      /// reset trigger
      triggeredTrackingStatus = TrackingStatus.none;
    } else {
      /// check for standing
      if (oldTrackingStatus == TrackingStatus.standing) {
        /// start check with assumed true value
        bool checkStartedMoving = true;

        /// check if all are outside distance treshold or alias radius
        for (var gps in gpsCalcPoints) {
          final distance =
              GPS.distance(gpsLastStatusStanding ?? gps, gps).round();
          if (distance <= gpsLocation.radius) {
            // still standing
            checkStartedMoving = false;
            break;
          }
        }
        if (checkStartedMoving) {
          newTrackingStatus = setStatusMoving(gps);
        }
      } else if (oldTrackingStatus == TrackingStatus.moving) {
        // assume we are standing
        bool isStanding = true;
        for (var point in gpsCalcPoints) {
          final distance = GPS.distance(gps, point).round();
          if (distance > gpsLocation.radius) {
            isStanding = false;
            break;
          }
        }

        if (isStanding) {
          newTrackingStatus = setStatusStanding(gps);

          /// autocreate alias?
          if ((await Cache.appSettingStatusStandingRequireAlias
                  .load<bool>(true)) &&
              gpsLocation.aliasModels.isEmpty) {
            try {
              /// autocreate must be activated
              if (await Cache.appSettingAutocreateAlias.load<bool>(false)) {
                /// check if enough time has passed
                if ((gpsLastStatusMoving ??= gps).time.isBefore(gps.time
                    .subtract(await Cache.appSettingAutocreateAliasDuration
                        .load<Duration>(AppUserSetting(
                                Cache.appSettingAutocreateAliasDuration)
                            .defaultValue as Duration)))) {
                  gps = GPS.average(gpsCalcPoints);
                  gps.time = DateTime.now();
                  await Cache.reload();
                  await (await GpsLocation.location(
                          gpsLastStatusStanding ?? gps))
                      .autocreateAlias();
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
      await Cache.reload();

      /// we started moving
      if (newTrackingStatus == TrackingStatus.moving) {
        // skip tracking by user
        if (!(await checkSkipTrackingByUser(stopSkip: true))) {
          logger.log('new tracking status MOVING');
          gpsLocation =
              await GpsLocation.location(gpsLastStatusStanding ?? gps);
          await gpsLocation.executeStatusMoving();
          logger.log('status MOVING finished');
        }

        ///
      } else if (newTrackingStatus == TrackingStatus.standing) {
        // skip tracking by user
        if (!(await checkSkipTrackingByUser())) {
          logger.log('new tracking status STANDING');
          await gpsLocation.executeStatusStanding();
          logger.log('status STANDING finished');
        }
      }
    }

    return await serializeState(gps);
  }

  Future<bool> checkSkipTrackingByUser({bool stopSkip = true}) async {
    // skip tracking by user
    if (await Cache.backgroundTrackPointSkipRecordOnce.load<bool>(false)) {
      if (stopSkip) {
        await Cache.backgroundTrackPointSkipRecordOnce.save<bool>(false);
      }
      return true;
    }
    return false;
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
    //await calculateSmoothPoints();

    /// extract calculation points from smoothed points
    gpsCalcPoints = gpsPoints
        .getRange(
            0,
            math.min(
                gpsPoints.length - 1,
                (timeRangeTreshold.inSeconds / trackpointInterval.inSeconds)
                    .ceil()))
        .toList();

    gps = gpsCalcPoints.first;
/* 
    /// all gps points calculated, save them
    await Cache.backgroundLastGps.save<GPS>(gps);
    gpsPoints = await Cache.backgroundGpsPoints.save<List<GPS>>(gpsPoints);
    gpsSmoothPoints =
        await Cache.backgroundGpsSmoothPoints.save<List<GPS>>(gpsSmoothPoints);
    gpsCalcPoints =
        await Cache.backgroundGpsCalcPoints.save<List<GPS>>(gpsCalcPoints);
 */
    return gps;
  }

  TrackingStatus setStatusStanding(GPS gps) {
    trackingStatus = TrackingStatus.standing;
    gpsLastStatusChange = gps;
    gpsLastStatusStanding = gps;
    return trackingStatus!;
  }

  TrackingStatus setStatusMoving(GPS gps) {
    trackingStatus = TrackingStatus.moving;
    gpsLastStatusChange = gps;
    gpsLastStatusMoving = gps;
    return trackingStatus!;
  }
/* 
  Future<void> calculateSmoothPoints() async {
    gpsSmoothPoints.clear();
    gpsSmoothPoints.addAll(gpsPoints);
    return;
    int smoothCount = await Cache.appSettingGpsPointsSmoothCount.load<int>(
        AppUserSetting(Cache.appSettingGpsPointsSmoothCount).defaultValue
            as int);
    if (smoothCount < 2 || gpsPoints.length <= smoothCount) {
      /// smoothing is disabled
      gpsSmoothPoints.addAll(gpsPoints);
      return;
    }
    int index = 0;
    int range = gpsPoints.length - smoothCount;
    while (index < range) {
      try {
        var averageGps = GPS
            .average(gpsPoints.getRange(index, index + smoothCount).toList());
        averageGps.time = gpsPoints[index].time;
        gpsSmoothPoints.add(averageGps);
      } catch (e, stk) {
        logger.error('calculateSmoothPoints: $e', stk);
      }
      index++;
    }
  } */
}
