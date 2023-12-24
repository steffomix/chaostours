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

  GPS? gpsLastStatusChange;
  GPS? gpsLastStatusStanding;
  GPS? gpsLastStatusMoving;
  List<GPS> gpsPoints = [];
  List<GPS> gpsSmoothPoints = [];
  List<GPS> gpsCalcPoints = [];

  /// initials
  TrackingStatus oldTrackingStatus = TrackingStatus.standing;
  TrackingStatus trackingStatus = TrackingStatus.standing;

  Address? address;

  Map<String, dynamic> serializeState(GPS gps) {
    return {
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
          TypeAdapter.serializeTrackingStatus(trackingStatus),
      DataChannelKey.lastAddress.toString(): address?.alias ?? '-',
      DataChannelKey.lastFullAddress.toString(): address?.description ?? '-',
    };
  }

  Future<Map<String, dynamic>> track() async {
    /// create gpsPoint
    GPS gps = await GPS.gps();

    if (await Cache.backgroundTrackingStatus.load(TrackingStatus.none) ==
        TrackingStatus.none) {
      /// initialize basic events if not set
      /// this must be done before loading last session
      await Cache.backgroundGpsStartMoving.save<GPS>(gps);
      await Cache.backgroundGpsStartStanding.save<GPS>(gps);
      await Cache.backgroundGpsLastStatusChange.save<GPS>(gps);

      /// app start, no status yet
      await Cache.backgroundTrackingStatus
          .save<TrackingStatus>(TrackingStatus.standing);
    }

    bool appSettingStatusStandingRequireAlias = await Cache
        .appSettingStatusStandingRequireAlias
        .load<bool>(AppUserSetting(Cache.appSettingStatusStandingRequireAlias)
            .defaultValue as bool);

    Duration autoCreateAliasDefault =
        AppUserSetting(Cache.appSettingAutocreateAliasDuration).defaultValue
            as Duration;

    Duration appSettingAutoCreateAliasDuration = await Cache
        .appSettingAutocreateAliasDuration
        .load<Duration>(autoCreateAliasDefault);

    Duration appSettingsTrackpointInterval =
        await Cache.appSettingBackgroundTrackingInterval.load<Duration>(
            AppUserSetting(Cache.appSettingBackgroundTrackingInterval)
                .defaultValue as Duration);

    Duration appSettingTimeRangeTreshold =
        await Cache.appSettingTimeRangeTreshold.load<Duration>(
            AppUserSetting(Cache.appSettingTimeRangeTreshold).defaultValue
                as Duration);

    bool publishToCalendar = await Cache.appSettingPublishToCalendar.load<bool>(
        AppUserSetting(Cache.appSettingPublishToCalendar).defaultValue as bool);

    int maxGpsPoints = ((appSettingAutoCreateAliasDuration.inSeconds == 0
                ? autoCreateAliasDefault.inSeconds
                : appSettingAutoCreateAliasDuration.inSeconds) /
            appSettingsTrackpointInterval.inSeconds)
        .ceil();

    gpsPoints.insert(0, gps);

    if (gpsPoints.length != maxGpsPoints) {
      /// prefill gpsPoints
      while (gpsPoints.length <= maxGpsPoints) {
        var gpsFiller = GPS(gps.lat, gps.lon);
        gpsFiller.time = gpsPoints.last.time.add(appSettingsTrackpointInterval);
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
                (appSettingTimeRangeTreshold.inSeconds /
                        appSettingsTrackpointInterval.inSeconds)
                    .ceil()))
        .toList();

    /// continue with smoothed gps
    gps = gpsCalcPoints.first;

    /// all gps points calculated, save them
    await Cache.backgroundLastGps.save<GPS>(gps);
    await Cache.backgroundGpsPoints.save<List<GPS>>(gpsPoints);
    await Cache.backgroundGpsSmoothPoints.save<List<GPS>>(gpsSmoothPoints);
    await Cache.backgroundGpsCalcPoints.save<List<GPS>>(gpsCalcPoints);

    /// collect gps related data
    Location gpsLocation = await Location.location(gps);

    int distanceTreshold = gpsLocation.aliasModels.firstOrNull?.radius ??
        await Cache.appSettingDistanceTreshold.load<int>(
            AppUserSetting(Cache.appSettingDistanceTreshold).defaultValue
                as int);

    /// cache alias list
    await Cache.backgroundAliasIdList.save<List<int>>(gpsLocation.aliasIds);

    /// remember old status
    TrackingStatus newTrackingStatus = oldTrackingStatus = await Cache
        .backgroundTrackingStatus
        .load<TrackingStatus>(TrackingStatus.none);

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

      if (triggeredTrackingStatus == TrackingStatus.standing) {
        newTrackingStatus = await cacheNewStatusStanding(gps);

        /// process user trigger moving
      } else if (triggeredTrackingStatus == TrackingStatus.moving) {
        newTrackingStatus = await cacheNewStatusMoving(gps);
      }
    } else {
      /// check for standing
      if (oldTrackingStatus == TrackingStatus.standing) {
        /// start check with assumed true value
        bool checkStartedMoving = true;

        GPS gpsStandingStartet = await Cache.backgroundGpsStartStanding
            .load<GPS>(gpsCalcPoints.last);

        /// check if all calc points are below distance treshold
        for (var gps in gpsCalcPoints) {
          if (GPS.distance(gpsStandingStartet, gps) <= distanceTreshold) {
            // still standing
            checkStartedMoving = false;
            break;
          }
        }
        if (checkStartedMoving) {
          newTrackingStatus = await cacheNewStatusMoving(gps);
        }
      } else if (oldTrackingStatus == TrackingStatus.moving) {
        /// autocreate alias?
        if (appSettingStatusStandingRequireAlias && !gpsLocation.hasAlias) {
          try {
            /// autocreate must be activated
            if (appSettingAutoCreateAliasDuration.inMinutes > 0) {
              /// check if enough time has passed
              if ((await Cache.backgroundGpsStartMoving.load<GPS>(gps))
                  .time
                  .isBefore(
                      gps.time.subtract(appSettingAutoCreateAliasDuration))) {
                /// check if all points are in radius
                bool checkAllPointsInside = true;
                for (var sm in gpsSmoothPoints) {
                  if (GPS.distance(sm, gps) > distanceTreshold) {
                    checkAllPointsInside = false;
                    break;
                  }
                }

                /// all conditions met, auto create alias
                if (checkAllPointsInside) {
                  GPS createAliasGps = GPS.average(gpsCalcPoints);

                  /// get address
                  address = await Address(gps).lookup(
                      OsmLookupConditions.onAutoCreateAlias,
                      saveToCache: true);

                  createAliasGps.time = DateTime.now();

                  /// create alias
                  ModelAlias newAlias = ModelAlias(
                      gps: createAliasGps,
                      lastVisited: gpsSmoothPoints.last.time,
                      timesVisited: 1,
                      title: address?.alias ?? Address.messageDenyAddressLookup,
                      description: address?.description ?? '',
                      radius: distanceTreshold);
                  logger.warn('auto create new alias');
                  await newAlias.insert();

                  /// recreate location with new alias
                  gpsLocation = await Location.location(createAliasGps);

                  /// update cache alias list
                  await Cache.backgroundAliasIdList
                      .save<List<int>>(gpsLocation.aliasIds);

                  /// change status
                  gps.time = gpsSmoothPoints.last.time;
                  await cacheNewStatusStanding(gps);
                }
              }
            }
          } catch (e, stk) {
            logger.error('autocreate alias: $e', stk);
          }
        } else {
          if (GPS.distanceOverTrackList(gpsCalcPoints) < distanceTreshold) {
            await cacheNewStatusStanding(gps);
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
      ///
      /// ---------- status changed -----------
      ///
      ///
    } else {
      /// update osm address
      address = await Address(gps)
          .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);

      /// we started moving
      if (newTrackingStatus == TrackingStatus.moving) {
        logger.log('tracking status MOVING');

        List<ModelAlias> aliases =
            await ModelAlias.byRadius(gps: gps, radius: distanceTreshold);

        ///
        ///     --- insert and update database entrys ---
        ///
        if (!appSettingStatusStandingRequireAlias ||
            (appSettingStatusStandingRequireAlias && aliases.isNotEmpty)) {
          /// create and insert new trackpoint
          ModelTrackPoint newTrackPoint = ModelTrackPoint(
              gps: gps,
              timeStart:
                  (await Cache.backgroundGpsStartStanding.load<GPS>(gps)).time,
              timeEnd: gps.time,
              calendarEventIds: await Cache.backgroundCalendarLastEventIds
                  .load<List<CalendarEventId>>([CalendarEventId()]),
              address: address?.alias ?? Address.messageDenyAddressLookup,
              notes:
                  await Cache.backgroundTrackPointUserNotes.load<String>(''));

          /// save new TrackPoint with user- and task ids
          await newTrackPoint.insert();

          /// execute calendar
          if (publishToCalendar &&
              !gpsLocation.isPrivate &&
              (!appSettingStatusStandingRequireAlias ||
                  (appSettingStatusStandingRequireAlias &&
                      newTrackPoint.aliasModels.isNotEmpty))) {
            try {
              var calendar = AppCalendar();
              await calendar.completeCalendarEvent(newTrackPoint);
            } catch (e, stk) {
              logger.error('completeCalendarEvent; $e', stk);
            }
          }

          /// reset calendarEvent ID
          await Cache.backgroundCalendarLastEventIds
              .save<List<CalendarEventId>>([]);

          /// update alias
          if (gpsLocation.hasAlias) {
            for (var model in gpsLocation.aliasModels) {
              model.lastVisited =
                  (await Cache.backgroundGpsStartStanding.load<GPS>(gps)).time;
              await model.update();
            }
            // wait before shutdown task
            await Future.delayed(const Duration(seconds: 1));
          }

          /// reset user data
          await Cache.backgroundTaskIdList.save<List<int>>([]);
          await Cache.backgroundTrackPointUserNotes.save<String>('');
          logger.log('status MOVING finished');
        } else {
          logger.log(
              'New trackpoint not saved due to app settings- or alias restrictions');
        }

        ///
      } else if (newTrackingStatus == TrackingStatus.standing) {
        logger.log('new tracking status STANDING');

        /// cache alias id list
        await Cache.backgroundAliasIdList.save<List<int>>(gpsLocation.aliasIds);

        bool publishToCalendar = await Cache.appSettingPublishToCalendar
            .load<bool>(AppUserSetting(Cache.appSettingPublishToCalendar)
                .defaultValue as bool);

        /// create calendar entry from cache data
        if (publishToCalendar &&
            !gpsLocation.isPrivate &&
            (!appSettingStatusStandingRequireAlias ||
                (appSettingStatusStandingRequireAlias &&
                    gpsLocation.hasAlias))) {
          logger.log('create new calendar event');
          try {
            await AppCalendar()
                .startCalendarEvent(await ModelTrackPoint.fromCache(gps));
          } catch (e, stk) {
            logger.error('startCalendarEvent: $e', stk);
          }
        }
        logger.log('tracking status STANDING finished');
      }
    }

    return serializeState(gps);
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
