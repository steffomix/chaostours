import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';

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
  TrackPoint._() {
    Logger.prefix = '~~';
    Logger.backgroundLogger = true;
    bridge = DataBridge.instance;
  }
  factory TrackPoint() => _instance ??= TrackPoint._();

  TrackingStatus oldTrackingStatus = TrackingStatus.none;
  List<ModelAlias> aliasWorkList = [];

  late DataBridge bridge;

  Future<void> startShared({required double lat, required double lon}) async {
    // reload shared preferences
    await Cache.reload();
    // load global settings
    await Globals.loadSettings();

    /// create gpsPoint
    PendingGps gps = PendingGps(lat, lon);
    GPS.lastGps = gps;

    /// initialize basic events if not set
    /// this must be done before loading last session
    bridge.trackPointGpsStartMoving ??= await Cache.setValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsStartMoving, gps);
    bridge.trackPointGpsStartStanding ??= await Cache.setValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsStartStanding, gps);
    bridge.trackPointGpslastStatusChange ??= await Cache.setValue<PendingGps>(
        CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);

    // load last session data
    await bridge.loadBackgroundSession();

    /// load if user triggered status change to moving
    await bridge.loadTriggerStatus();

    /// clear is obsolete except its running in forground
    bridge.gpsPoints.clear();
    try {
      bridge.gpsPoints.add(gps);
      bridge.gpsPoints.addAll(bridge.gpsPoints);

      if (bridge.trackingStatus == TrackingStatus.none) {
        /// app start, no status yet
        bridge.trackingStatus = TrackingStatus.standing;
      }

      /// prune down to 10 times of gpsPoints needed for one time range calculation
      /// except we are moving
      if (bridge.trackingStatus != TrackingStatus.moving) {
        while (bridge.gpsPoints.length >
            (Globals.timeRangeTreshold.inSeconds /
                    Globals.trackPointInterval.inSeconds *
                    10)
                .round()) {
          // don't remove the very last.
          // it's required to measure durations
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

      // load database
      await ModelTrackPoint.open();
      await ModelAlias.open();

      /// update alias if needed
      if (bridge.trackingStatus == TrackingStatus.moving) {
        bridge.trackPointAliasIdList =
            ModelAlias.nextAlias(gps: gps).map((e) => e.id).toList();
      }

      for (var id in bridge.trackPointAliasIdList) {
        aliasWorkList.add(ModelAlias.getAlias(id));
      }

      /// remember old status
      oldTrackingStatus = bridge.trackingStatus;

      ///
      /// heart of this whole app:
      /// process trackpoint for new status
      ///
      trackPoint();

      /// if nothing has changed, nothing to do
      if (bridge.trackingStatus == oldTrackingStatus) {
        /// if nothing changed simply write data back
        await Cache.setValue<PendingGps>(
            CacheKeys.cacheBackgroundLastGps, bridge.lastGps ?? gps);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundGpsPoints, bridge.gpsPoints);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundSmoothGpsPoints, bridge.smoothGpsPoints);
        await Cache.setValue<List<PendingGps>>(
            CacheKeys.cacheBackgroundCalcGpsPoints, bridge.calcGpsPoints);
        return;
      } else {
        if (bridge.trackingStatus == TrackingStatus.moving) {
          /// update osm address
          if (Globals.osmLookupCondition == OsmLookup.onStatus) {
            await bridge.setAddress(gps);
          }

          ///
          ///     ---- save event data ---
          ///

          /// save new start moving event
          bridge.trackPointGpsStartMoving = await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsStartMoving, gps);

          /// save general status changed event
          bridge.trackPointGpslastStatusChange =
              await Cache.setValue<PendingGps>(
                  CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);

          ///
          ///   --- update alias models from cached list ---
          ///
          List<ModelAlias> aliasFilteredList = [];

          /// filter alias list
          for (var model in aliasWorkList) {
            try {
              if (!model.deleted && model.status != AliasStatus.restricted) {
                aliasFilteredList.add(model);
              }
            } catch (e, stk) {
              logger.error('select alias from cached idList: $e', stk);
            }
          }

          ///
          ///     --- insert and update database entrys ---
          ///
          if ((!Globals.statusStandingRequireAlias ||
              (Globals.statusStandingRequireAlias &&
                  aliasFilteredList.isNotEmpty))) {
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
            await Cache.reload();
          } else {
            logger.log(
                'New trackpoint not saved due to app settings- or alias restrictions');
          }

          ///
        } else if (bridge.trackingStatus == TrackingStatus.standing) {
          /// lookup address if wanted
          if (Globals.osmLookupCondition == OsmLookup.onStatus) {
            await bridge.setAddress(gps);
          }

          /// new status is standing
          /// save events
          bridge.trackPointGpsStartStanding = await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsStartStanding, gps);
          bridge.trackPointGpslastStatusChange =
              await Cache.setValue<PendingGps>(
                  CacheKeys.cacheEventBackgroundGpsLastStatusChange, gps);

          List<ModelAlias> aliasFilteredList = [];

          /// select alias list
          for (ModelAlias model in aliasWorkList) {
            if (model.deleted || model.status == AliasStatus.restricted) {
              // don't add deleted or restricted items
              continue;
            }
            aliasFilteredList.add(model);
          }

          /// cache alias id list if wanted
          if (aliasFilteredList.isNotEmpty &&
              (!Globals.statusStandingRequireAlias ||
                  (Globals.statusStandingRequireAlias &&
                      aliasFilteredList.isNotEmpty))) {
            bridge.trackPointAliasIdList = await Cache.setValue<List<int>>(
                CacheKeys.cacheBackgroundAliasIdList,
                aliasFilteredList.map((e) => e.id).toList());
          }

          await Cache.setValue<String>(
              CacheKeys.cacheBackgroundTrackPointUserNotes, '');
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

      /// lookup address on every interval
      if (Globals.osmLookupCondition == OsmLookup.always) {
        await bridge.setAddress(gps);
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    // wait before shutdown task
    await Future.delayed(const Duration(seconds: 1));
  }

  void calculateSmoothPoints() {
    int smooth = Globals.gpsPointsSmoothCount;
    if (smooth < 2) {
      bridge.smoothGpsPoints.addAll(bridge.gpsPoints);
      return;
    }
    if (bridge.gpsPoints.length <= smooth) {
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
    // get gpsPoints of globals time range
    // to measure movement
    var points = bridge.smoothGpsPoints;
    bridge.calcGpsPoints.clear();
    if (bridge.smoothGpsPoints.length > 1) {
      List<PendingGps> gpsList = [];
      int tRef = points.first.time.millisecondsSinceEpoch;
      int dur = Globals.timeRangeTreshold.inMilliseconds;
      int tUntil = tRef - dur;

      bool fullTresholdRange = false;
      for (var gps in points) {
        if (gps.time.millisecondsSinceEpoch >= tUntil) {
          gpsList.add(gps);
        } else {
          fullTresholdRange = true;
          break;
        }
      }
      if (fullTresholdRange) {
        bridge.calcGpsPoints.addAll(gpsList);
      }
    }
  }

  void trackPoint() {
    DataBridge bridge = DataBridge.instance;

    /// status change triggered by user
    if ((bridge.trackingStatus == TrackingStatus.standing ||
            bridge.trackingStatus == TrackingStatus.none) &&
        bridge.statusTriggered) {
      bridge.trackingStatus = TrackingStatus.moving;
      bridge.triggerStatusExecuted();
      return;
    }

    /// gps calc points min count
    if (bridge.calcGpsPoints.length < 2) {
      return;
    }

    /// check if we started moving
    /// try to calculate how far away we are from last standing point
    if (bridge.trackingStatus == TrackingStatus.standing ||
        bridge.trackingStatus == TrackingStatus.none) {
      if (GPS.distance(bridge.calcGpsPoints.first,
              bridge.trackPointGpsStartMoving ?? bridge.calcGpsPoints.last) >
          (aliasWorkList.isEmpty
              ? Globals.distanceTreshold
              : aliasWorkList.first.radius)) {
        bridge.trackingStatus = TrackingStatus.moving;
      }

      /// check if we stopped moving
      /// using smoothGpsPoints because calcGpsPoints are way too few for calculation
    } else if (bridge.trackingStatus == TrackingStatus.moving) {
      if (GPS.distanceOverTrackList(bridge.calcGpsPoints) <
          Globals.distanceTreshold) {
        bridge.trackingStatus = TrackingStatus.standing;
      }
    }
  }
}
