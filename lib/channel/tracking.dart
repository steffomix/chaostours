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
import 'package:chaostours/shared/shared_trackpoint_location.dart';

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

  int defaultDistanceTreshold =
      AppUserSetting(Cache.appSettingDistanceTreshold).defaultValue as int;

  bool statusStandingRequireLocation =
      AppUserSetting(Cache.appSettingStatusStandingRequireLocation).defaultValue
          as bool;

  DateTime upTimeStart = DateTime.now();

  List<GPS> gpsPoints = [];
  List<GPS> gpsSmoothPoints = [];
  List<GPS> gpsCalcPoints = [];

  Duration statusDuration = Duration.zero;

  TrackingStatus triggeredTrackingStatus = TrackingStatus.none;

  bool skipRecord = false;

  /// initials
  TrackingStatus oldTrackingStatus = TrackingStatus.standing;
  TrackingStatus? trackingStatus = TrackingStatus.standing;

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

    gpsLastStatusMoving ??= gps;
    gpsLastStatusStanding ??= gps;
    gpsLastStatusChange ??= gps;

    // load always used cache data

    const cacheDistanceTreshold = Cache.appSettingDistanceTreshold;
    defaultDistanceTreshold = await cacheDistanceTreshold
        .load<int>(AppUserSetting(cacheDistanceTreshold).defaultValue as int);

    const cacheStandingRequireLocation =
        Cache.appSettingStatusStandingRequireLocation;
    statusStandingRequireLocation =
        await cacheStandingRequireLocation.load<bool>(
            AppUserSetting(cacheStandingRequireLocation).defaultValue as bool);

    //gps = await
    await claculateGPSPoints(gps);

    /// collect gps related data
    GpsLocation gpsLocation = await GpsLocation.gpsLocation(gps, true);

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
        gpsPoints.clear();
        gps = await claculateGPSPoints(gps);
        gpsLocation = await GpsLocation.gpsLocation(gps);
        // status changed by user
        newTrackingStatus = setStatusStanding(gps);
      }

      /// reset trigger
      triggeredTrackingStatus = TrackingStatus.none;
    } else {
      /// check for standing
      if (oldTrackingStatus == TrackingStatus.standing) {
        //
        if (!(await checkIfStillStanding(gpsLocation))) {
          newTrackingStatus = setStatusMoving(gps);
        }
      } else if (oldTrackingStatus == TrackingStatus.moving) {
        await autoCreateLocation(gpsLocation);
        bool isStillMoving = await checkIfStillMoving(gpsLocation);

        if (!isStillMoving) {
          newTrackingStatus = setStatusStanding(gps);
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
      oldTrackingStatus = newTrackingStatus;

      /// we started moving
      if (newTrackingStatus == TrackingStatus.moving) {
        // skip tracking by user
        if (!skipRecord) {
          logger.log('new tracking status MOVING');
          gpsLocation =
              await GpsLocation.gpsLocation(gpsLastStatusStanding ?? gps);
          await gpsLocation.executeStatusMoving();
          logger.log('status MOVING finished');
        }
        skipRecord = false;

        ///
      } else if (newTrackingStatus == TrackingStatus.standing) {
        // skip tracking by user
        if (!skipRecord) {
          logger.log('new tracking status STANDING');
          await gpsLocation.executeStatusStanding();
          logger.log('status STANDING finished');
        }
      }
    }

    return await serializeState(gps);
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

  Future<void> autoCreateLocation(GpsLocation gpsLocation) async {
    if (gpsLocation.locationModels.isNotEmpty) {
      return;
    }

    final gps = gpsLocation.gpsOfLocation;

    Cache cache = Cache.appSettingDefaultLocationRadius;
    int radius =
        await cache.load<int>(AppUserSetting(cache).defaultValue as int);

    cache = Cache.appSettingAutoCreateLocation;
    if (await cache.load<bool>(AppUserSetting(cache).defaultValue as bool)) {
      const cache = Cache.appSettingAutocreateLocationDuration;
      final duration = await cache
          .load<Duration>(AppUserSetting(cache).defaultValue as Duration);

      /// check if enough time has passed
      if ((gpsLastStatusMoving ??= gps)
          .time
          .add(duration)
          .isBefore(DateTime.now())) {
        final averageGps = GPS.average(gpsPoints);
        // check if all gps points are in default radius
        for (var point in gpsPoints) {
          if (GPS.distance(point, averageGps) > radius) {
            return;
          }
        }
        averageGps.time = DateTime.now().subtract(duration);
        await (await GpsLocation.gpsLocation(averageGps)).autocreateLocation();
      }
    }
  }

  /// true if at least one is out of radius
  bool atLeastOneIsOutside(GPS gps, int radius) {
    for (var point in gpsCalcPoints) {
      if (GPS.distance(gps, point) > radius) {
        return true;
      }
    }
    return false;
  }

  /// true if at least one is out of radius
  bool atLeastOneIsInside(GPS gps, int radius) {
    for (var point in gpsCalcPoints) {
      if (GPS.distance(gps, point) < radius) {
        return true;
      }
    }
    return false;
  }

  Future<bool> checkIfStillMoving(GpsLocation gpsLocation) async {
    if (gpsLocation.locationModels.isEmpty && statusStandingRequireLocation) {
      return true;
    }

    if (gpsLocation.locationModels.isEmpty &&
        !statusStandingRequireLocation &&
        !atLeastOneIsOutside(
            gpsLocation.gpsOfLocation, defaultDistanceTreshold)) {
      return false;
    }

    if (gpsLocation.locationModels.isNotEmpty &&
        !atLeastOneIsOutside(gpsLocation.gpsOfLocation, gpsLocation.radius)) {
      return false;
    }

    return true;
  }

  // returns false if started moving or satnding is not allowed
  // otherwise execute status standing
  Future<bool> checkIfStillStanding(GpsLocation gpsLocation) async {
    if (gpsLocation.locationModels.isNotEmpty ||
        !statusStandingRequireLocation) {
      return atLeastOneIsInside(
          gpsLastStatusStanding ?? gpsLocation.gpsOfLocation,
          gpsLocation.radius);
    }

    // standing not allowed
    if (gpsLocation.locationModels.isEmpty && statusStandingRequireLocation) {
      return atLeastOneIsInside(
          gpsLastStatusStanding ?? gpsLocation.gpsOfLocation,
          gpsLocation.radius);
    }

    // moved away from last standing location
    if (gpsLocation.locationModels.isEmpty &&
        !statusStandingRequireLocation &&
        !atLeastOneIsInside(gpsLastStatusStanding ?? gpsLocation.gpsOfLocation,
            defaultDistanceTreshold)) {
      return false;
    }
    // moved away from location
    if (gpsLocation.locationModels.isNotEmpty &&
        !atLeastOneIsInside(gpsLastStatusStanding ?? gpsLocation.gpsOfLocation,
            gpsLocation.radius)) {
      return false;
    }

    return atLeastOneIsInside(
        gpsLastStatusStanding ?? gpsLocation.gpsOfLocation, gpsLocation.radius);
  }

  Future<GPS> claculateGPSPoints(GPS gps) async {
    Duration autoCreateLocationDefault =
        AppUserSetting(Cache.appSettingAutocreateLocationDuration).defaultValue
            as Duration;

    Duration autoCreateLocationDuration = await Cache
        .appSettingAutocreateLocationDuration
        .load<Duration>(autoCreateLocationDefault);

    Duration trackpointInterval =
        await Cache.appSettingBackgroundTrackingInterval.load<Duration>(
            AppUserSetting(Cache.appSettingBackgroundTrackingInterval)
                .defaultValue as Duration);

    Duration timeRangeTreshold = await Cache.appSettingTimeRangeTreshold
        .load<Duration>(AppUserSetting(Cache.appSettingTimeRangeTreshold)
            .defaultValue as Duration);

    int maxGpsPoints = ((autoCreateLocationDuration.inSeconds == 0
                ? autoCreateLocationDefault.inSeconds
                : autoCreateLocationDuration.inSeconds) /
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
    return gps;
  }
}
