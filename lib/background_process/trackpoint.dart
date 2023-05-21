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
import 'package:chaostours/trackpoint_data.dart';
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/calendar.dart';

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

class TrackPoint {
  final Logger logger = Logger.logger<TrackPoint>();

  static TrackPoint? _instance;
  TrackPoint._();
  factory TrackPoint() => _instance ??= TrackPoint._();

  TrackingStatus oldTrackingStatus = TrackingStatus.none;

  DataBridge bridge = DataBridge.instance;

  Future<void> track({required double lat, required double lon}) async {
    try {
      var exec = DateTime.now();

      /// create gpsPoint
      PendingGps gps = PendingGps(lat, lon);
      GPS.lastGps = gps;

      /// reload shared preferences
      await Cache.reload();

      /// load database
      await ModelTrackPoint.open();
      await ModelAlias.open();

      /// load global settings
      await Globals.loadSettings();

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
            CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.standing);
      }

      /// load if user triggered status change to moving
      await bridge.loadTriggerStatus();
      int maxGpsPoints = (Globals.timeRangeTreshold.inSeconds /
              Globals.trackPointInterval.inSeconds *
              10)
          .round();

      /// prefill gpsPoints
      while (bridge.gpsPoints.length < maxGpsPoints) {
        bridge.gpsPoints.insert(0, gps);
      }

      /// add current gps point
      bridge.gpsPoints.insert(0, gps);

      /// prune gpsPoints
      if (bridge.trackingStatus != TrackingStatus.moving) {
        while (bridge.gpsPoints.length > maxGpsPoints) {
          bridge.gpsPoints.removeAt(bridge.gpsPoints.length - 2);
        }
      }

      /// filter gps points for trackpoint calculation
      calculateSmoothPoints();
      calculateCalcPoints();

      /// continue with smoothed gps
      gps = bridge.calcGpsPoints.first;

      /// select and filter alias list from given gps
      List<ModelAlias> aliasList = [];
      bool locationIsPrivate = false;
      bool locationIsRestricted = false;
      for (var model in ModelAlias.nextAlias(gps: gps)) {
        if (!model.deleted) {
          aliasList.add(model);
        } else {
          continue;
        }
        if (model.status == AliasStatus.privat) {
          locationIsPrivate = true;
        }
        if (model.status == AliasStatus.restricted) {
          locationIsPrivate = true;
          locationIsRestricted = true;
        }
      }

      /// cache alias list
      bridge.trackPointAliasIdList = await Cache.setValue<List<int>>(
          CacheKeys.cacheBackgroundAliasIdList,
          aliasList.map((model) => model.id).toList());

      /// remember old status
      oldTrackingStatus = bridge.trackingStatus;

      ///
      /// process trackpoint
      ///
      ///
      /// process user trigger standing
      if (bridge.triggeredTrackingStatus == TrackingStatus.standing) {
        await cacheNewStatusStanding(gps);

        /// process user trigger moving
      } else if (bridge.triggeredTrackingStatus == TrackingStatus.moving) {
        await cacheNewStatusMoving(gps);

        /// check for standing
      } else if (oldTrackingStatus == TrackingStatus.standing) {
        int distanceTreshold = aliasList.isEmpty
            ? Globals.distanceTreshold
            : aliasList.first.radius;
        PendingGps location =
            bridge.trackPointGpsStartStanding ?? bridge.calcGpsPoints.last;
        bool startedMoving = true;

        /// check if all calc points are below distance treshold
        for (var gps in bridge.calcGpsPoints) {
          if (GPS.distance(location, gps) <= distanceTreshold) {
            // still standing
            startedMoving = false;
            break;
          }
        }
        if (startedMoving) {
          await cacheNewStatusMoving(gps);
        }
      } else {
        /// to calculate standing simply add path distance over all calc points
        if (GPS.distanceOverTrackList(bridge.calcGpsPoints) <
            Globals.distanceTreshold) {
          await cacheNewStatusStanding(gps);
        }
      }

      /// always reset TrackingStatus trigger
      bridge.triggeredTrackingStatus = await Cache.setValue<TrackingStatus>(
          CacheKeys.cacheTriggerTrackingStatus, TrackingStatus.none);

      if (locationIsRestricted) {
        logger.log('location is restricted, skip processing status change');
        Duration d = DateTime.now().difference(exec);
        logger.log(
            'Executed background gps in ${d.inSeconds}.${d.inMilliseconds} seconds');
        return;
      }

      /// if nothing has changed, nothing to do
      if (bridge.trackingStatus == oldTrackingStatus) {
        /// lookup address on every interval
        if (Globals.osmLookupCondition == OsmLookup.always) {
          await bridge.setAddress(gps);
        }

        /// if nothing changed simply write data back
        await Cache.setValue<PendingGps>(
            CacheKeys.cacheBackgroundLastGps, bridge.lastGps ?? gps);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundGpsPoints, bridge.gpsPoints);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundSmoothGpsPoints, bridge.smoothGpsPoints);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundCalcGpsPoints, bridge.calcGpsPoints);

        ///
        ///
        /// ---------- status changed -----------
        ///
        ///
      } else {
        /// update osm address
        if (Globals.osmLookupCondition == OsmLookup.onStatus) {
          await bridge.setAddress(gps);
        }

        /// we started moving
        if (bridge.trackingStatus == TrackingStatus.moving) {
          ///
          ///     --- insert and update database entrys ---
          ///
          if (!Globals.statusStandingRequireAlias ||
              (Globals.statusStandingRequireAlias && aliasList.isNotEmpty)) {
            /// create and insert new trackpoint
            ModelTrackPoint newTrackPoint = ModelTrackPoint(
                gps: gps,
                idAlias: aliasList.map((e) => e.id).toList(),
                timeStart: bridge.trackPointGpsStartStanding?.time ?? gps.time);
            newTrackPoint.address = bridge.currentAddress;
            newTrackPoint.status = oldTrackingStatus;
            newTrackPoint.timeEnd = gps.time;
            newTrackPoint.idTask = bridge.trackPointTaskIdList;
            newTrackPoint.idUser = bridge.trackPointUserIdList;
            newTrackPoint.notes = bridge.trackPointUserNotes;
            newTrackPoint.calendarId =
                '${bridge.selectedCalendarId};${bridge.lastCalendarEventId}';

            /// insert
            await ModelTrackPoint.insert(newTrackPoint);

            /// complete calendar event from trackpoint data
            /// only if no private or restricted alias is present
            if (!locationIsPrivate) {
              await ModelTask.open();
              await ModelUser.open();
              await AppCalendar()
                  .completeCalendarEvent(TrackPointData(tp: newTrackPoint));
            }

            /// reset calendarEvent ID
            bridge.lastCalendarEventId =
                await Cache.setValue<String>(CacheKeys.lastCalendarEventId, '');

            /// update alias
            if (aliasList.isNotEmpty) {
              for (var model in aliasList) {
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
          } else {
            logger.log(
                'New trackpoint not saved due to app settings- or alias restrictions');
          }

          ///
        } else if (bridge.trackingStatus == TrackingStatus.standing) {
          /// create calendar entry from cache data

          if (!locationIsPrivate &&
              (!Globals.statusStandingRequireAlias ||
                  (Globals.statusStandingRequireAlias &&
                      aliasList.isNotEmpty))) {
            await ModelTask.open();
            await ModelUser.open();
            var id = await AppCalendar().startCalendarEvent(TrackPointData());

            /// cache event id
            bridge.lastCalendarEventId = await Cache.setValue<String>(
                CacheKeys.lastCalendarEventId, id ?? '');
          }
        }

        /// write back gps points
        await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundLastGps, gps);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundGpsPoints, bridge.gpsPoints);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundSmoothGpsPoints, bridge.smoothGpsPoints);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundCalcGpsPoints, bridge.calcGpsPoints);
      }

      /// log success
      Duration d = DateTime.now().difference(exec);
      logger.log(
          'Executed background gps in ${d.inSeconds}.${d.inMilliseconds} seconds');
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
    int smooth = Globals.gpsPointsSmoothCount;
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
      if (bridge.smoothGpsPoints.isNotEmpty) {
        int m = GPS.distance(gps, bridge.smoothGpsPoints.last).round();
        int s = Globals.trackPointInterval.inSeconds;
        double ms = m / s;
        double kmh = ms * 3.6;
        if (kmh > Globals.gpsMaxSpeed) {
          logger.warn('calculate smooth gps with $kmh speed');
        }
      }

      gps.time = bridge.gpsPoints[index].time;
      bridge.smoothGpsPoints.add(gps);
      index++;
    }
  }

  /// calc points are not added until time range is fulfilled
  void calculateCalcPoints() {
    /// reset calcPoints
    bridge.calcGpsPoints.clear();
    if (bridge.smoothGpsPoints.length > 1) {
      List<PendingGps> gpsList = [];
      bool fullTresholdRange = false;

      /// most recent gps time in ms
      int tRef = bridge.smoothGpsPoints.first.time.millisecondsSinceEpoch;

      /// duration in ms
      int dur = Globals.timeRangeTreshold.inMilliseconds;

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
