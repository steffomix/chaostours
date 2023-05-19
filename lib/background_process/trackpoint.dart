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
  final Logger logger = Logger.logger<TrackPoint>(
      specialBackgroundLogger: true,
      specialLogLevel: LogLevel.verbose,
      specialPrefix: '~~');

  static TrackPoint? _instance;
  TrackPoint._() {
    bridge = DataBridge.instance;
  }
  factory TrackPoint() => _instance ??= TrackPoint._();

  TrackingStatus oldTrackingStatus = TrackingStatus.none;

  late DataBridge bridge;

  Future<void> startShared({required double lat, required double lon}) async {
    var t = DateTime.now();
    logger.log(
        'Processing Background GPS with lat:$lat, lon:$lon at time: ${t.hour}:${t.minute}:${t.second}');

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

    try {
      bridge.gpsPoints.insert(0, gps);

      /// prune down to 10 times of gpsPoints needed for one time range calculation
      /// except we are moving
      if (bridge.trackingStatus != TrackingStatus.moving) {
        while (bridge.gpsPoints.length >
            (Globals.timeRangeTreshold.inSeconds /
                    Globals.trackPointInterval.inSeconds *
                    10)
                .round()) {
          /// don't remove the very last.
          /// it's required to measure durations
          bridge.gpsPoints.removeAt(bridge.gpsPoints.length - 2);
        }
      }

      /// filter points for trackpoint calculation
      ///
      calculateSmoothPoints();
      calculateCalcPoints();

      /// get a secure calc point if user has triggered status change
      if (bridge.calcGpsPoints.isNotEmpty) {
        gps = bridge.calcGpsPoints.first;
      } else if (bridge.smoothGpsPoints.isNotEmpty) {
        gps = bridge.smoothGpsPoints.first;
      } else {
        gps = gps;
      }

      /// remember old status
      oldTrackingStatus = bridge.trackingStatus;

      ///
      /// heart of this whole app:
      /// process trackpoint for new status
      ///
      trackPoint();

      /// reset TrackingStatus trigger
      bridge.triggeredTrackingStatus = await Cache.setValue<TrackingStatus>(
          CacheKeys.cacheTriggerTrackingStatus, TrackingStatus.none);

      /// if nothing has changed, nothing to do
      if (bridge.trackingStatus == oldTrackingStatus) {
        /// lookup address on every interval
        if (Globals.osmLookupCondition == OsmLookup.always) {
          await bridge.setAddress(gps);
        }

        /// update alias if moving
        if (bridge.trackingStatus == TrackingStatus.moving) {
          bridge.trackPointAliasIdList.clear();
          for (var model in ModelAlias.nextAlias(gps: gps)) {
            bridge.trackPointAliasIdList.add(model.id);
          }
          await Cache.setValue<List<int>>(CacheKeys.cacheBackgroundAliasIdList,
              bridge.trackPointAliasIdList);
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
      } else {
        ///
        ///
        /// ---------- status changed -----------
        ///
        ///
        /// update osm address
        if (Globals.osmLookupCondition == OsmLookup.onStatus) {
          await bridge.setAddress(gps);
        }

        /// we started moving
        if (bridge.trackingStatus == TrackingStatus.moving) {
          /// save new start moving event
          bridge.trackPointGpsStartMoving = await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsStartMoving, gps);

          bridge.trackingStatus = await Cache.setValue<TrackingStatus>(
              CacheKeys.cacheBackgroundTrackingStatus, bridge.trackingStatus);

          ///
          ///   --- update alias models from cached list ---
          ///

          /// load and filter alias models from cached idList
          List<ModelAlias> aliasFilteredList = [];
          bool locationIsPrivate = false;
          bool locationIsRestricted = false;
          for (var id in bridge.trackPointAliasIdList) {
            var model = ModelAlias.getAlias(id);
            if (model.status == AliasStatus.privat) {
              locationIsPrivate = true;
            }
            if (model.status == AliasStatus.restricted) {
              locationIsRestricted = true;
            }
            if (!model.deleted && model.status != AliasStatus.restricted) {
              aliasFilteredList.add(model);
            }
          }

          ///
          ///     --- insert and update database entrys ---
          ///
          if (!Globals.statusStandingRequireAlias ||
              (Globals.statusStandingRequireAlias &&
                  aliasFilteredList.isNotEmpty)) {
            /// create and insert new trackpoint
            ModelTrackPoint newTrackPoint = ModelTrackPoint(
                gps: gps,
                idAlias: aliasFilteredList.map((e) => e.id).toList(),
                timeStart: bridge.trackPointGpsStartStanding?.time ??
                    gps.time.subtract(Globals.timeRangeTreshold));
            newTrackPoint.address = bridge.currentAddress;
            newTrackPoint.status = oldTrackingStatus;
            newTrackPoint.timeEnd =
                gps.time.subtract(Globals.trackPointInterval);
            newTrackPoint.idTask = bridge.trackPointTaskIdList;
            newTrackPoint.idUser = bridge.trackPointUserIdList;
            newTrackPoint.notes = bridge.trackPointUserNotes;

            await ModelTrackPoint.insert(newTrackPoint);

            /// update alias
            if (aliasFilteredList.isNotEmpty) {
              for (var model in aliasFilteredList) {
                model.lastVisited = bridge.trackPointGpsStartStanding!.time;
                model.timesVisited++;
              }
              await ModelAlias.write();
            }

            /// only if no private or restricted alias is present
            if (!(locationIsPrivate || locationIsRestricted)) {
              await completeCalendarEvent(newTrackPoint);
            }

            /// save general status changed event AFTER saving
            bridge.trackPointGpslastStatusChange =
                await Cache.setValue<PendingGps>(
                    CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);

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
          /// new status is standing
          /// save events
          bridge.trackPointGpsStartStanding = await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsStartStanding, gps);
          bridge.trackPointGpslastStatusChange =
              await Cache.setValue<PendingGps>(
                  CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);

          await Cache.setValue<TrackingStatus>(
              CacheKeys.cacheBackgroundTrackingStatus, bridge.trackingStatus);

          /// add calendar entry
          bool private = false;
          List<ModelAlias> aliasList = ModelAlias.nextAlias(gps: gps);
          for (var model in aliasList) {
            if (model.status == AliasStatus.privat ||
                model.status == AliasStatus.restricted) {
              private = true;
              break;
            }
          }

          if (!private) {
            await startCalendarEvent();
          }

          /// reset user data
          await Cache.setValue<String>(
              CacheKeys.cacheBackgroundTrackPointUserNotes, '');
          await Cache.setValue<List<int>>(
              CacheKeys.cacheBackgroundTaskIdList, []);
        }

        /// general cleanup on status change
        bridge.gpsPoints.clear();
        bridge.gpsPoints.add(gps);

        await Cache.setValue<PendingGps>(CacheKeys.cacheBackgroundLastGps, gps);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundGpsPoints, [gps]);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundSmoothGpsPoints, []);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundCalcGpsPoints, []);
      }
    } catch (e, stk) {
      logger.error('start shared: $e', stk);
    }

    // wait before shutdown task
    await Future.delayed(const Duration(seconds: 1));
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

  void trackPoint() {
    /// process user trigger standing
    if (bridge.triggeredTrackingStatus == TrackingStatus.standing) {
      bridge.trackingStatus = TrackingStatus.standing;
      return;
    }

    /// process user trigger moving
    if (bridge.triggeredTrackingStatus == TrackingStatus.moving) {
      bridge.trackingStatus = TrackingStatus.moving;
      return;
    }

    /// gps calc points min count
    if (bridge.calcGpsPoints.isEmpty) {
      return;
    }

    /// check if we started moving
    /// all calc gps points need to be out of standing area
    if (bridge.trackingStatus == TrackingStatus.standing) {
      var aliasList = bridge.trackPointAliasIdList
          .map((id) => ModelAlias.getAlias(id))
          .toList();
      int distance =
          aliasList.isEmpty ? Globals.distanceTreshold : aliasList.first.radius;
      PendingGps location =
          bridge.trackPointGpsStartStanding ?? bridge.calcGpsPoints.last;
      bool moving = true;
      for (var gps in bridge.calcGpsPoints) {
        if (GPS.distance(location, gps) <= distance) {
          // still standing
          moving = false;
          break;
        }
      }
      if (moving) {
        bridge.trackingStatus = TrackingStatus.moving;
        return;
      }
    }

    /// check if we stopped moving
    /// calc distance over calc gps points
    if (bridge.trackingStatus == TrackingStatus.moving) {
      if (GPS.distanceOverTrackList(bridge.calcGpsPoints) <
          Globals.distanceTreshold) {
        bridge.trackingStatus = TrackingStatus.standing;

        return;
      }
    }
  }

  Future<void> startCalendarEvent() async {
    var tpData = TrackPointData();

    var appCalendar = AppCalendar();
    await appCalendar.retrieveCalendars();
    if (appCalendar.calendars.isNotEmpty) {
      /// get dates
      final berlin = getLocation('Europe/Berlin');
      var start = TZDateTime.from(tpData.tStart, berlin);
      var end = start.add(const Duration(minutes: 2));

      /// get calendar
      Calendar? calendar = await appCalendar.getCalendarfromCacheId();

      /// get lastEvent
      if (calendar != null) {
        var title =
            'Ankunft ${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText} - ${start.hour}.${start.minute}';
        var location =
            'maps.google.com?q=${tpData.gpslastStatusChange.lat},${tpData.gpslastStatusChange.lon}';
        var description =
            '${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText}\n'
            'am ${start.day}.${start.month}.${start.year}\n'
            'um ${start.hour}.${start.minute} - unbekannt)\n\n'
            'Arbeiten: ...\n\n'
            'Mitarbeiter:\n${tpData.usersText}\n\n'
            'Notizen: ...';
        Event event = Event(calendar.id,
            title: title,
            start: start,
            end: end,
            location: location,
            description: description);
        var id = await appCalendar.inserOrUpdate(event);
        if (id?.data != null) {
          await Cache.setValue<String>(
              CacheKeys.lastCalendarEventId, id!.data!);
        }
      }
    }
  }

  Future<void> completeCalendarEvent(ModelTrackPoint tpModel) async {
    try {
      await ModelTask.open();
      await ModelUser.open();
      var tpData = TrackPointData();
      var appCalendar = AppCalendar();
      await appCalendar.retrieveCalendars();
      if (appCalendar.calendars.isNotEmpty) {
        /// get dates
        final berlin = getLocation('Europe/Berlin');
        var start = TZDateTime.from(tpData.tStart, berlin);
        var end = TZDateTime.from(tpData.tEnd, berlin);

        /// get calendar
        Calendar? calendar = await appCalendar.getCalendarfromCacheId();

        /// get lastEvent
        if (calendar != null) {
          Event? lastEvent =
              await appCalendar.getEventById(bridge.lastCalendarEventId);
          String? eventId;
          if (lastEvent != null) {
            eventId = lastEvent.eventId;
          }

          var title =
              '${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText}; ${tpData.durationText}';
          var location =
              'maps.google.com?q=${tpData.gpslastStatusChange.lat},${tpData.gpslastStatusChange.lon}';
          var description =
              '${tpData.aliasList.isNotEmpty ? tpData.aliasList.first.alias : tpData.addressText}\n'
              '${start.day}.${start.month}. - ${tpData.durationText}\n'
              '(${start.hour}.${start.minute} - ${end.hour}.${end.minute})\n\n'
              'Arbeiten:\n${tpData.tasksText}\n\n'
              'Mitarbeiter:\n${tpData.usersText}\n\n'
              'Notizen: ${tpData.trackPointNotes.isEmpty ? '-' : tpData.trackPointNotes}';
          Event event = Event(calendar.id,
              eventId: eventId,
              title: title,
              start: start,
              end: end,
              location: location,
              description: description);
          await appCalendar.inserOrUpdate(event);
          await Cache.setValue<String>(CacheKeys.lastCalendarEventId, '');
        }
      }
    } catch (e, stk) {
      logger.error('addCalendarEvent: $e', stk);
    }
  }
}
