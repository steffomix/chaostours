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

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/address.dart';
import 'dart:math' as math;

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/trackpoint_data.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/location.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/database.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';

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
  static bool _initialized = false;

  static Future<AndroidConfig> _androidConfig() async {
    return AndroidConfig(
        channelName: 'Chaos Tours Unlimited Background Tracking',
        notificationBody:
            'Background Tracking running, tap to open Chaos Tours App.',
        notificationIcon: 'drawable/explore',
        enableNotificationLocationUpdates: false,
        cancelTrackingActionText: 'Stop Tracking',
        enableCancelTrackingAction: true,
        trackingInterval: await Cache.appSettingForegroundUpdateInterval
            .load<Duration>(const Duration(seconds: 30)));
  }

  static Future<bool> isTracking() async {
    return await BackgroundLocationTrackerManager.isTracking();
  }

  static Future<void> startTracking() async {
    if (!_initialized) {
      await initialize();
    }
    if (!await isTracking()) {
      await initialize();
      BackgroundLocationTrackerManager.startTracking(
          config: await _androidConfig());
    }
  }

  static Future<void> stopTracking() async {
    if (await isTracking()) {
      await BackgroundLocationTrackerManager.stopTracking();
    }
  }

  ///
  static Future<void> initialize() async {
    await BackgroundLocationTrackerManager.initialize(backgroundCallback,
        config: BackgroundLocationTrackerConfig(
            androidConfig: await _androidConfig()));
    _initialized = true;
  }
}

Future<void> track(GPS gps) async {
  return _TrackPoint().track(lat: gps.lat, lon: gps.lon);
}

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

class _TrackPoint {
  final Logger logger = Logger.logger<_TrackPoint>();

  static _TrackPoint? _instance;
  _TrackPoint._();
  factory _TrackPoint() => _instance ??= _TrackPoint._();

  TrackingStatus oldTrackingStatus = TrackingStatus.none;

  //DataBridge bridge = DataBridge.instance;

  Future<void> track({required double lat, required double lon}) async {
    /// create gpsPoint
    GPS gps = GPS(lat, lon);

    /// load global settings
    await AppSettings.loadSettings();

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

    Duration appSettingAutoCreateAliasDuration = await Cache
        .appSettingAutocreateAlias
        .load<Duration>(AppSettings.autoCreateAliasDefault);

    Duration appSettingsTrackpointIntervalDuration = await Cache
        .appSettingForegroundUpdateInterval
        .load<Duration>(AppSettings.backgroundLookupDurationDefault);

    int maxGpsPoints = (appSettingAutoCreateAliasDuration.inSeconds == 0
            ? AppSettings.autoCreateAliasDefault.inSeconds / 60
            : appSettingAutoCreateAliasDuration.inSeconds /
                appSettingsTrackpointIntervalDuration.inSeconds)
        .ceil();

    /// add current gps point
    List<GPS> gpsPoints = await Cache.backgroundGpsPoints.load<List<GPS>>([]);
    gpsPoints.insert(0, gps);

    if (gpsPoints.length != maxGpsPoints) {
      /// prefill gpsPoints
      while (gpsPoints.length < maxGpsPoints) {
        var gpsFiller = GPS(gps.lat, gps.lon);
        gpsFiller.time =
            gpsPoints.last.time.add(AppSettings.trackPointInterval);
        gpsPoints.add(gpsFiller);
      }

      /// prune gpsPoints
      while (gpsPoints.length > maxGpsPoints) {
        gpsPoints.removeLast();
      }
    }

    /// filter gps points for trackpoint calculation
    List<GPS> smoothGpsPoints = calculateSmoothPoints(gpsPoints);

    /// extract calculation points from smoothed points
    List<GPS> calcGpsPoints = smoothGpsPoints
        .getRange(
            0,
            math.min(
                smoothGpsPoints.length - 1,
                (AppSettings.timeRangeTreshold.inSeconds /
                        AppSettings.trackPointInterval.inSeconds)
                    .ceil()))
        .toList();

    /// continue with smoothed gps
    gps = calcGpsPoints.first;

    /// all gps points calculated, save them
    await Cache.backgroundLastGps.save<GPS>(gps);
    await Cache.backgroundGpsPoints.save<List<GPS>>(gpsPoints);
    await Cache.backgroundSmoothGpsPoints.save<List<GPS>>(smoothGpsPoints);
    await Cache.backgroundCalcGpsPoints.save<List<GPS>>(calcGpsPoints);

    /// collect gps related data
    Location gpsLocation = await Location.location(gps);

    int distanceTreshold = gpsLocation.aliasModels.firstOrNull?.radius ??
        AppSettings.distanceTreshold;

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
    /// process user trigger standing
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
        /// start check with true value
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
        if (AppSettings.statusStandingRequireAlias && !gpsLocation.hasAlias) {
          try {
            /// autocreate must be activated
            if (AppSettings.autoCreateAlias.inMinutes > 0) {
              /// check if enough time has passed
              if ((await Cache.backgroundGpsStartMoving.load<GPS>(gps))
                  .time
                  .isBefore(gps.time.subtract(AppSettings.autoCreateAlias))) {
                /// check if all points are in radius
                bool checkAllPointsInside = true;
                for (var sm in smoothGpsPoints) {
                  if (GPS.distance(sm, gps) > AppSettings.distanceTreshold) {
                    checkAllPointsInside = false;
                    break;
                  }
                }

                /// all conditions met, auto create alias
                if (checkAllPointsInside) {
                  GPS createAliasGps = GPS.average(calcGpsPoints);

                  /// get address
                  String address = await saveAddress(gps);

                  createAliasGps.time = DateTime.now();

                  /// create alias
                  ModelAlias newAlias = ModelAlias(
                      gps: createAliasGps,
                      lastVisited: smoothGpsPoints.last.time,
                      timesVisited: 1,
                      title: address,
                      description:
                          'Auto created Alias\nat address:\n"$address"\n'
                          '\nat date/time: ${createAliasGps.time.toIso8601String()}',
                      radius: AppSettings.distanceTreshold);
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
          if (GPS.distanceOverTrackList(calcGpsPoints) <
              AppSettings.distanceTreshold) {
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
      if (AppSettings.osmLookupCondition == OsmLookupConditions.always) {
        await saveAddress(gps);
      }

      ///
      ///
      /// ---------- status changed -----------
      ///
      ///
    } else {
      /// update osm address
      if (AppSettings.osmLookupCondition ==
          OsmLookupConditions.onStatusChanged) {
        await saveAddress(gps);
      }

      /// we started moving
      if (newTrackingStatus == TrackingStatus.moving) {
        logger.log('tracking status MOVING');

        List<ModelAlias> aliases =
            await ModelAlias.byRadius(gps: gps, radius: distanceTreshold);

        ///
        ///     --- insert and update database entrys ---
        ///
        if (!AppSettings.statusStandingRequireAlias ||
            (AppSettings.statusStandingRequireAlias && aliases.isNotEmpty)) {
          /// create and insert new trackpoint
          ModelTrackPoint newTrackPoint = ModelTrackPoint(
              gps: gps,
              timeStart:
                  (await Cache.backgroundGpsStartStanding.load<GPS>(gps)).time,
              timeEnd: gps.time,
              calendarEventIds: await Cache.backgroundCalendarLastEventIds
                  .load<List<CalendarEventId>>([CalendarEventId()]),
              address: await Cache.backgroundLastStandingAddress
                  .load<String>(await saveAddress(gps)),
              notes:
                  await Cache.backgroundTrackPointUserNotes.load<String>(''));
          newTrackPoint.aliasIds = aliases
              .map(
                (e) => e.id,
              )
              .toList();
          newTrackPoint.taskIds =
              await Cache.backgroundTaskIdList.load<List<int>>([]);
          newTrackPoint.userIds =
              await Cache.backgroundUserIdList.load<List<int>>([]);

          /// complete calendar event from trackpoint data
          /// only if no private or restricted alias is present
          var tpData =
              await TrackPointData.trackPointData(trackPoint: newTrackPoint);

          /// save new TrackPoint with user- and task ids
          await newTrackPoint.insert();

          /// execute calendar
          if (AppSettings.publishToCalendar &&
              !gpsLocation.isPrivate &&
              (!AppSettings.statusStandingRequireAlias ||
                  (AppSettings.statusStandingRequireAlias &&
                      tpData.aliasModels.isNotEmpty))) {
            try {
              var calendar = AppCalendar();
              await calendar.completeCalendarEvent(tpData);
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
              model.lastVisited = await Cache.backgroundGpsStartStanding
                  .load<DateTime>(DateTime.now());
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

        await Cache.backgroundLastStandingAddress
            .save<String>(await saveAddress(gps));

        /// cache alias id list
        await Cache.backgroundAliasIdList.save<List<int>>(gpsLocation.aliasIds);

        /// create calendar entry from cache data
        if (AppSettings.publishToCalendar &&
            !gpsLocation.isPrivate &&
            (!AppSettings.statusStandingRequireAlias ||
                (AppSettings.statusStandingRequireAlias &&
                    gpsLocation.hasAlias))) {
          logger.log('create new calendar event');
          try {
            await AppCalendar()
                .startCalendarEvent(await TrackPointData.trackPointData());
          } catch (e, stk) {
            logger.error('startCalendarEvent: $e', stk);
          }
        }
        logger.log('tracking status STANDING finished');
      }
    }

    await Cache.backgroundLastTick.save<DateTime>(DateTime.now());

    await (Future.delayed(const Duration(seconds: 1)));
  }

  Future<String> saveAddress(GPS gps) async {
    String address = (await Address(gps).lookupAddress()).toString();
    return await Cache.backgroundAddress.save<String>(address);
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

  List<GPS> calculateSmoothPoints(List<GPS> gpsPoints) {
    List<GPS> smoothGpsPoints = [];
    int smooth = AppSettings.gpsPointsSmoothCount;
    if (smooth < 2) {
      /// smoothing is disabled
      smoothGpsPoints.addAll(gpsPoints);
      return smoothGpsPoints;
    }

    if (gpsPoints.length <= smooth) {
      logger.warn('too few gpsPoints for $smooth smoothPoints. '
          'Use all gpsPoints as smoothPoints directly without smmothing effect');
      smoothGpsPoints.addAll(gpsPoints);
      return smoothGpsPoints;
    }
    int index = 0;
    int range = gpsPoints.length - smooth;
    while (index < range) {
      try {
        var averageGps =
            GPS.average(gpsPoints.getRange(index, index + smooth).toList());
        averageGps.time = gpsPoints[index].time;
        smoothGpsPoints.add(averageGps);
      } catch (e, stk) {
        logger.error('calculateSmoothPoints: $e', stk);
      }
      index++;
    }
    return smoothGpsPoints;
  }
/*
  /// calc points are not added until time range is fulfilled
  void calculateCalcPoints() {
    /// reset calcPoints
    bridge.calcGpsPoints.clear();
    int p = (AppSettings.timeRangeTreshold.inSeconds /
            AppSettings.trackPointInterval.inSeconds)
        .ceil();
    if (bridge.smoothGpsPoints.length >= p) {
      bridge.calcGpsPoints.addAll(bridge.smoothGpsPoints.getRange(0, p));
    }
    if (bridge.smoothGpsPoints.length > 1) {
      List<GPS> gpsList = [];
      bool fullTresholdRange = false;

      /// most recent gps time in ms
      int tRef = bridge.smoothGpsPoints.first.time.millisecondsSinceEpoch;

      /// duration in ms
      int dur = AppSettings.timeRangeTreshold.inMilliseconds;

      /// max past time in ms
      int maxPast = tRef - dur;

      /// iter into the past
      for (var gps in bridge.smoothGpsPoints) {
        if (gps.time.millisecondsSinceEpoch >= maxPast) {
          gpsList.add(gps);
        } else {
          fullTresholdRange = true;
          break;
        }
      }

      /// add calcPoints only if time range is fulfilled
      if (fullTresholdRange) {
        bridge.calcGpsPoints.addAll(gpsList);
      }
    }
  }
  */
}
