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

//import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/address.dart';
import 'dart:math' as math;

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/location.dart';
import 'package:chaostours/calendar.dart';
//import 'package:chaostours/database.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';

/* 
@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    try {
      Logger.globalBackgroundLogger = true;
      Logger.globalLogLevel = LogLevel.verbose;
      Logger.defaultRealm = LoggerRealm.background;
      await DB.openDatabase(create: false);
      await _TrackPoint().track(lat: data.lat, lon: data.lon);
    } catch (e, stk) {
      Logger.logger<BackgroundLocationTrackerManager>().error(e, stk);
    }

    // wait before shutdown task
    await Future.delayed(const Duration(seconds: 1));
  });
}

class BackgroundTracking {
  static Logger logger = Logger.logger<BackgroundTracking>();

  static Future<AndroidConfig> _androidConfig() async {
    var cache = Cache.appSettingBackgroundTrackingInterval;
    var interval = await cache
        .load<Duration>(AppUserSetting(cache).defaultValue as Duration);

    return AndroidConfig(
        channelName: 'com.stefanbrinkmann.chaosToursUnlimited',
        //notificationBody: 'Background Tracking running, tap to open Chaos Tours App.',
        //notificationIcon: '@ic_launcher',
        //enableNotificationLocationUpdates: false,
        //cancelTrackingActionText: 'Stop Tracking',
        //enableCancelTrackingAction: false,
        trackingInterval: interval);
  }

  static Future<bool> isTracking() async {
    return await BackgroundLocationTrackerManager.isTracking();
  }

  static Future<void> startTracking() async {
    await BackgroundLocationTrackerManager.stopTracking();
    await Future.delayed(const Duration(seconds: 1));
    //await initialize();
    await BackgroundLocationTrackerManager.startTracking();
  }

  static Future<void> stopTracking() async {
    await BackgroundLocationTrackerManager.stopTracking();
  }

  ///
  static Future<void> initialize() async {
    await BackgroundLocationTrackerManager.initialize(backgroundCallback,
        config: BackgroundLocationTrackerConfig(
            loggingEnabled: false, androidConfig: await _androidConfig()));
  }
}
 */

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

  TrackingStatus oldTrackingStatus = TrackingStatus.none;

  static Future<GPS>? _gpsStartMoving;
  static Future<GPS> gpsStartMoving() => _gpsStartMoving ??= GPS.gps();

  Future<void> track() async {
    // gather info and stats
    if (logger.realm == LoggerRealm.background) {
      var tick = DateTime.now();
      await Cache.backgroundLastTick.save<DateTime>(tick);
      var tickList = await Cache.backgroundTickList.load<List<DateTime>>([]);
      tickList.insert(0, tick);
      while (tickList.length > 10) {
        tickList.removeLast();
      }
      logger.log(
          'last background duration: ${tick.difference(tickList.length <= 1 ? tick : tickList[1]).abs().inMilliseconds}');
      await Cache.backgroundTickList.save<List<DateTime>>(tickList);
    }

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
          .save<TrackingStatus>(TrackingStatus.moving);
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

    int maxGpsPoints = ((appSettingAutoCreateAliasDuration.inSeconds == 0
                ? autoCreateAliasDefault.inSeconds
                : appSettingAutoCreateAliasDuration.inSeconds) /
            appSettingsTrackpointInterval.inSeconds)
        .ceil();

    /// add current gps point
    List<GPS> gpsPoints = await Cache.backgroundGpsPoints.load<List<GPS>>([]);

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
    List<GPS> smoothGpsPoints = await calculateSmoothPoints(gpsPoints);

    Duration appSettingTimeRangeTreshold =
        await Cache.appSettingTimeRangeTreshold.load<Duration>(
            AppUserSetting(Cache.appSettingTimeRangeTreshold).defaultValue
                as Duration);

    /// extract calculation points from smoothed points
    List<GPS> calcGpsPoints = smoothGpsPoints
        .getRange(
            0,
            math.min(
                smoothGpsPoints.length - 1,
                (appSettingTimeRangeTreshold.inSeconds /
                        appSettingsTrackpointInterval.inSeconds)
                    .ceil()))
        .toList();

    /// continue with smoothed gps
    gps = calcGpsPoints.first;

    /// all gps points calculated, save them
    await Cache.backgroundLastGps.save<GPS>(gps);
    await Cache.backgroundGpsPoints.save<List<GPS>>(gpsPoints);
    await Cache.backgroundGpsSmoothPoints.save<List<GPS>>(smoothGpsPoints);
    await Cache.backgroundGpsCalcPoints.save<List<GPS>>(calcGpsPoints);

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
            .load<GPS>(calcGpsPoints.last);

        /// check if all calc points are below distance treshold
        for (var gps in calcGpsPoints) {
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
                for (var sm in smoothGpsPoints) {
                  if (GPS.distance(sm, gps) > distanceTreshold) {
                    checkAllPointsInside = false;
                    break;
                  }
                }

                /// all conditions met, auto create alias
                if (checkAllPointsInside) {
                  GPS createAliasGps = GPS.average(calcGpsPoints);

                  /// get address
                  Address address = await Address(gps).lookup(
                      OsmLookupConditions.onAutoCreateAlias,
                      saveToCache: true);

                  createAliasGps.time = DateTime.now();

                  /// create alias
                  ModelAlias newAlias = ModelAlias(
                      gps: createAliasGps,
                      lastVisited: smoothGpsPoints.last.time,
                      timesVisited: 1,
                      title: address.alias,
                      description: address.description,
                      radius: distanceTreshold);
                  logger.warn('auto create new alias');
                  await newAlias.insert();

                  /// recreate location with new alias
                  gpsLocation = await Location.location(createAliasGps);

                  /// update cache alias list
                  await Cache.backgroundAliasIdList
                      .save<List<int>>(gpsLocation.aliasIds);

                  /// change status
                  gps.time = smoothGpsPoints.last.time;
                  await cacheNewStatusStanding(gps);
                }
              }
            }
          } catch (e, stk) {
            logger.error('autocreate alias: $e', stk);
          }
        } else {
          if (GPS.distanceOverTrackList(calcGpsPoints) < distanceTreshold) {
            await cacheNewStatusStanding(gps);
          }
        }
      }
    }

    if (gpsLocation.isRestricted) {
      logger.log('location is restricted, skip processing status change');
      return;
    }

    /// if nothing has changed, nothing to do
    if (newTrackingStatus == oldTrackingStatus) {
      /// lookup address on every interval
      await Address(gps)
          .lookup(OsmLookupConditions.onBackgroundGps, saveToCache: true);

      ///
      ///
      /// ---------- status changed -----------
      ///
      ///
    } else {
      /// update osm address
      Address address = await Address(gps)
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
              address: address.alias,
              notes:
                  await Cache.backgroundTrackPointUserNotes.load<String>(''));

          /// save new TrackPoint with user- and task ids
          await newTrackPoint.insert();

          bool publishToCalendar = await Cache.appSettingPublishToCalendar
              .load<bool>(AppUserSetting(Cache.appSettingPublishToCalendar)
                  .defaultValue as bool);

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

    //await (Future.delayed(const Duration(seconds: 1)));
  }

  Future<TrackingStatus> cacheNewStatusStanding(GPS gps) async {
    await Cache.backgroundTrackingStatus
        .save<TrackingStatus>(TrackingStatus.standing);
    await Cache.backgroundGpsStartStanding.save<GPS>(gps);
    await Cache.backgroundGpsLastStatusChange.save<GPS>(gps);
    return TrackingStatus.standing;
  }

  Future<TrackingStatus> cacheNewStatusMoving(GPS gps) async {
    await Cache.backgroundTrackingStatus
        .save<TrackingStatus>(TrackingStatus.moving);
    await Cache.backgroundGpsStartMoving.save<GPS>(gps);
    await Cache.backgroundGpsLastStatusChange.save<GPS>(gps);
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
