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

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/trackpoint_data.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/Location.dart';
import 'package:chaostours/conf/osm.dart';

import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/calendar.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    Logger.globalBackgroundLogger = true;
    Logger.globalLogLevel = LogLevel.verbose;
    Logger.globalPrefix = '~~';
    await _TrackPoint().track(lat: data.lat, lon: data.lon);

    // wait before shutdown task
    await Future.delayed(const Duration(seconds: 1));
  });
}

class BackgroundTracking {
  static bool _initialized = false;

  static AndroidConfig _androidConfig() {
    return AndroidConfig(
        channelName: 'Chaos Tours Background Tracking',
        notificationBody:
            'Background Tracking running, tap to open Chaos Tours App.',
        notificationIcon: 'drawable/explore',
        enableNotificationLocationUpdates: false,
        cancelTrackingActionText: 'Stop Tracking',
        enableCancelTrackingAction: true,
        trackingInterval: AppSettings.trackPointInterval);
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
      BackgroundLocationTrackerManager.startTracking(config: _androidConfig());
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
        config:
            BackgroundLocationTrackerConfig(androidConfig: _androidConfig()));
    _initialized = true;
  }
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

  DataBridge bridge = DataBridge.instance;

  Future<void> track({required double lat, required double lon}) async {
    try {
      /// create gpsPoint
      PendingGps gps = PendingGps(lat, lon);

      /// reload shared preferences
      await Cache.reload();

      /// debug cheats
      double latShift =
          await Cache.getValue<double>(CacheKeys.gpsLatShift, 0.0);
      double lonShift =
          await Cache.getValue<double>(CacheKeys.gpsLonShift, 0.0);
      gps.lat += latShift;
      gps.lon += lonShift;

      /// load database
      await ModelTrackPoint.open();
      await ModelAlias.open();

      /// load global settings
      await AppSettings.loadSettings();

      /// load last session data
      await bridge.loadCache(gps);

      if (bridge.trackingStatus == TrackingStatus.none) {
        /// initialize basic events if not set
        /// this must be done before loading last session
        bridge.trackPointGpsStartMoving = await Cache.setValue<PendingGps>(
            CacheKeys.cacheEventBackgroundGpsStartMoving, gps);
        bridge.trackPointGpsStartStanding = await Cache.setValue<PendingGps>(
            CacheKeys.cacheEventBackgroundGpsStartStanding, gps);
        bridge.trackPointGpslastStatusChange = await Cache.setValue<PendingGps>(
            CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);

        /// app start, no status yet
        bridge.trackingStatus = await Cache.setValue<TrackingStatus>(
            CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.moving);
      }

      int maxGpsPoints = (AppSettings.autoCreateAlias.inSeconds /
              AppSettings.trackPointInterval.inSeconds)
          .round();

      /// add current gps point
      bridge.gpsPoints.insert(0, gps);

      /// prefill gpsPoints
      if (bridge.gpsPoints.length != maxGpsPoints) {
        while (bridge.gpsPoints.length < maxGpsPoints) {
          var gpsFiller = PendingGps(gps.lat, gps.lon);
          gpsFiller.time =
              bridge.gpsPoints.last.time.add(AppSettings.trackPointInterval);
          bridge.gpsPoints.add(gpsFiller);
        }

        while (bridge.gpsPoints.length > maxGpsPoints) {
          bridge.gpsPoints.removeLast();
        }
      }

      /// filter gps points for trackpoint calculation
      calculateSmoothPoints();

      /// get calculation range from smoothPoints
      bridge.calcGpsPoints.clear();
      int calculationRange = (AppSettings.timeRangeTreshold.inSeconds /
              AppSettings.trackPointInterval.inSeconds)
          .ceil();
      bridge.calcGpsPoints
          .addAll(bridge.smoothGpsPoints.getRange(0, calculationRange));

      /// continue with smoothed gps
      gps = bridge.calcGpsPoints.first;

      /// all gps points calculated, save them
      await Cache.setValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundGpsPoints, bridge.gpsPoints);
      await Cache.setValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundSmoothGpsPoints, bridge.smoothGpsPoints);
      await Cache.setValue<List<PendingGps>>(
          CacheKeys.cacheBackgroundCalcGpsPoints, bridge.calcGpsPoints);
      await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundLastGps, gps);

      Location gpsLocation = Location(gps);

      /// cache alias list
      bridge.currentAliasIdList = await Cache.setValue<List<int>>(
          CacheKeys.cacheCurrentAliasIdList, gpsLocation.aliasIdList);

      /// remember old status
      oldTrackingStatus = bridge.trackingStatus;

      ///
      /// process trackpoint
      ///
      ///
      /// process user trigger standing
      if (bridge.triggeredTrackingStatus != TrackingStatus.none) {
        if (bridge.triggeredTrackingStatus == TrackingStatus.standing) {
          await cacheNewStatusStanding(gps);

          /// process user trigger moving
        } else if (bridge.triggeredTrackingStatus == TrackingStatus.moving) {
          await cacheNewStatusMoving(gps);
        }
      } else {
        /// check for standing
        if (oldTrackingStatus == TrackingStatus.standing) {
          ///
          int distanceTreshold = AppSettings.distanceTreshold;
          if (bridge.trackPointAliasIdList.isNotEmpty) {
            try {
              distanceTreshold =
                  ModelAlias.getAlias(bridge.trackPointAliasIdList.first)
                      .radius;
            } catch (e) {
              if (gpsLocation.hasAlias) {
                distanceTreshold = gpsLocation.aliasModelList.first.radius;
              }
            }
          }

          PendingGps calculatedLocation =
              bridge.trackPointGpsStartStanding ?? bridge.calcGpsPoints.last;
          bool startedMoving = true;

          /// check if all calc points are below distance treshold
          for (var gps in bridge.calcGpsPoints) {
            if (GPS.distance(calculatedLocation, gps) <= distanceTreshold) {
              // still standing
              startedMoving = false;
              break;
            }
          }
          if (startedMoving) {
            await cacheNewStatusMoving(gps);
          }
        } else if (oldTrackingStatus == TrackingStatus.moving) {
          /// to calculate standing simply add path distance over all calc points
          if (AppSettings.statusStandingRequireAlias && !gpsLocation.hasAlias) {
            /// autocreate alias
            try {
              /// autocreate must be activated
              if (AppSettings.autoCreateAlias.inMinutes > 0) {
                if ((bridge.trackPointGpsStartMoving?.time ?? gps.time)
                    .isBefore(gps.time.subtract(AppSettings.autoCreateAlias))) {
                  bool allPointsInside = true;
                  for (var sm in bridge.calcGpsPoints) {
                    if (GPS.distance(sm, gps) > AppSettings.distanceTreshold) {
                      allPointsInside = false;
                      break;
                    }
                  }

                  ///
                  if (allPointsInside) {
                    String address = AppSettings.osmLookupCondition ==
                                OsmLookupConditions.onStatus ||
                            AppSettings.osmLookupCondition ==
                                OsmLookupConditions.always
                        ? await bridge.setAddress(gps)
                        : '';
                    ModelAlias newAlias = ModelAlias(
                        alias: address,
                        lat: gps.lat,
                        lon: gps.lon,
                        lastVisited: DateTime.now(),
                        timesVisited: 1,
                        radius: AppSettings.distanceTreshold);
                    logger.error('autocreate alias skipped in line 290',
                        StackTrace.empty);
                    //ModelAlias.insert(newAlias);
                  }
                }
              }
            } catch (e, stk) {
              logger.error('autocreate alias: $e', stk);
            }
          } else {
            if (GPS.distanceOverTrackList(bridge.calcGpsPoints) <
                AppSettings.distanceTreshold) {
              await cacheNewStatusStanding(gps);
            }
          }
        }
      }

      /// always reset TrackingStatus trigger
      bridge.triggeredTrackingStatus = await Cache.setValue<TrackingStatus>(
          CacheKeys.cacheTriggerTrackingStatus, TrackingStatus.none);

      if (gpsLocation.isRestricted) {
        logger.log('location is restricted, skip processing status change');
        return;
      }

      /// if nothing has changed, nothing to do
      if (bridge.trackingStatus == oldTrackingStatus) {
        /// lookup address on every interval
        if (AppSettings.osmLookupCondition == OsmLookupConditions.always) {
          await bridge.setAddress(gps);
        }

        ///
        ///
        /// ---------- status changed -----------
        ///
        ///
      } else {
        /// update osm address
        if (AppSettings.osmLookupCondition == OsmLookupConditions.onStatus) {
          await bridge.setAddress(gps);
        }

        await ModelTask.open();
        await ModelUser.open();

        /// we started moving
        if (bridge.trackingStatus == TrackingStatus.moving) {
          logger.warn('tracking status MOVING');

          ///
          ///     --- insert and update database entrys ---
          ///
          if (!AppSettings.statusStandingRequireAlias ||
              (AppSettings.statusStandingRequireAlias &&
                  bridge.trackPointAliasIdList.isNotEmpty)) {
            /// create and insert new trackpoint
            ModelTrackPoint newTrackPoint = ModelTrackPoint(
                gps: gps,
                idAlias: bridge.trackPointAliasIdList,
                timeStart: bridge.trackPointGpsStartStanding?.time ?? gps.time);
            newTrackPoint.address = bridge.lastStandingAddress;
            newTrackPoint.status = oldTrackingStatus;
            newTrackPoint.timeEnd = gps.time;
            newTrackPoint.idTask = bridge.trackPointTaskIdList;
            newTrackPoint.idUser = bridge.trackPointUserIdList;
            newTrackPoint.notes = bridge.trackPointUserNotes;
            newTrackPoint.calendarId =
                '${bridge.selectedCalendarId};${bridge.lastCalendarEventId}';

            /// complete calendar event from trackpoint data
            /// only if no private or restricted alias is present
            var tpData = TrackPointData(tp: newTrackPoint);
            if (!gpsLocation.isPrivate &&
                (!AppSettings.statusStandingRequireAlias ||
                    (AppSettings.statusStandingRequireAlias &&
                        tpData.aliasList.isNotEmpty))) {
              logger.warn('complete calendar event');
              await AppCalendar()
                  .completeCalendarEvent(TrackPointData(tp: newTrackPoint));
            }

            /// calendar eventId may have changed
            /// save after completing calendar event
            await ModelTrackPoint.insert(newTrackPoint);

            /// reset calendarEvent ID
            bridge.lastCalendarEventId =
                await Cache.setValue<String>(CacheKeys.lastCalendarEventId, '');

            /// update alias
            if (gpsLocation.hasAlias) {
              for (var model in gpsLocation.aliasModelList) {
                model.lastVisited = bridge.trackPointGpsStartStanding!.time;
                model.timesVisited++;
              }
              await ModelAlias.write();
              // wait before shutdown task
              await Future.delayed(const Duration(seconds: 1));
            }

            /// reset user data
            await Cache.setValue<List<int>>(
                CacheKeys.cacheBackgroundTaskIdList, []);
            await Cache.setValue<String>(
                CacheKeys.cacheBackgroundTrackPointUserNotes, '');
            logger.warn('status MOVING finished');
          } else {
            logger.warn(
                'New trackpoint not saved due to app settings- or alias restrictions');
          }

          ///
        } else if (bridge.trackingStatus == TrackingStatus.standing) {
          logger.warn('tracking status STANDING');

          bridge.lastStandingAddress = await Cache.setValue<String>(
              CacheKeys.cacheBackgroundLastStandingAddress,
              AppSettings.osmLookupCondition == OsmLookupConditions.never
                  ? ''
                  : bridge.currentAddress);

          /// cache alias id list
          bridge.trackPointAliasIdList = await Cache.setValue<List<int>>(
              CacheKeys.cacheBackgroundAliasIdList, gpsLocation.aliasIdList);

          /// create calendar entry from cache data
          if (!gpsLocation.isPrivate &&
              (!AppSettings.statusStandingRequireAlias ||
                  (AppSettings.statusStandingRequireAlias &&
                      gpsLocation.hasAlias))) {
            logger.warn('create new calendar event');
            String? id =
                await AppCalendar().startCalendarEvent(TrackPointData());

            /// cache event id
            bridge.lastCalendarEventId = await Cache.setValue<String>(
                CacheKeys.lastCalendarEventId, id ?? '');
          }
          logger.warn('tracking status STANDING finished');
        }
      }
    } catch (e, stk) {
      logger.error('processing background gps: $e', stk);
    }
  }

  Future<void> cacheNewStatusStanding(PendingGps gps) async {
    bridge.trackingStatus = await Cache.setValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.standing);
    bridge.trackPointGpsStartStanding = await Cache.setValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsStartStanding, gps);
    bridge.trackPointGpslastStatusChange = await Cache.setValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);
  }

  Future<void> cacheNewStatusMoving(PendingGps gps) async {
    bridge.trackingStatus = await Cache.setValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.moving);
    bridge.trackPointGpsStartMoving = await Cache.setValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsStartMoving, gps);
    bridge.trackPointGpslastStatusChange = await Cache.setValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);
  }

  void calculateSmoothPoints() {
    bridge.smoothGpsPoints.clear();
    int smooth = AppSettings.gpsPointsSmoothCount;
    if (smooth < 2) {
      /// smoothing is disabled
      bridge.smoothGpsPoints.addAll(bridge.gpsPoints);
      return;
    }

    if (bridge.gpsPoints.length <= smooth) {
      /// too few gps points
      return;
    }

    int index = 0;
    while (index <= bridge.gpsPoints.length - 1 - smooth) {
      double smoothLat = 0;
      double smoothLon = 0;
      for (var i = 1; i <= smooth; i++) {
        smoothLat += bridge.gpsPoints[index + i - 1].lat;
        smoothLon += bridge.gpsPoints[index + i - 1].lon;
      }
      smoothLat /= smooth;
      smoothLon /= smooth;
      PendingGps gps = PendingGps(smoothLat, smoothLon);
      /*
      if (bridge.smoothGpsPoints.isNotEmpty) {
        int m = GPS.distance(gps, bridge.smoothGpsPoints.last).round();
        int s = Globals.trackPointInterval.inSeconds;
        double ms = m / s;
        double kmh = ms * 3.6;
        if (kmh > Globals.gpsMaxSpeed) {
          logger.warn('calculate smooth gps with $kmh speed');
        }
      }
      */
      gps.time = bridge.gpsPoints[index].time;
      bridge.smoothGpsPoints.add(gps);
      index++;
    }
  }

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
      List<PendingGps> gpsList = [];
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
}
