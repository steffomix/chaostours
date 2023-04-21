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
  }
  factory TrackPoint() => _instance ??= TrackPoint._();

  /// int _nextId = 0;
  /// contains all trackpoints from current state start or stop
  final List<PendingGps> gpsPoints = [];
  final List<PendingGps> smoothGpsPoints = [];
  final List<PendingGps> calcGpsPoints = [];

  TrackingStatus currentTrackingStatus = TrackingStatus.none;
  TrackingStatus oldTrackingStatus = TrackingStatus.none;

  Future<void> startShared({required double lat, required double lon}) async {
    // reload shared preferences
    await DataBridge.reload();
    // init dataBridge
    DataBridge bridge = DataBridge.instance;
    // load global settings
    await Globals.loadSettings();

    /// create gpsPoint
    PendingGps gps = PendingGps(lat, lon);
    GPS.lastGps = gps;
    // if not yet set, do it right now
    bridge.trackPointGpsStartMoving ??= gps;
    bridge.trackPointGpsStartStanding ??= gps;
    bridge.trackPointGpslastStatusChange ??= gps;

    // load last session data
    await bridge.loadBackgroundSession();

    /// load if user triggered status change to moving
    await bridge.loadTriggerStatus();

    /// copy a shorthand for processing trackpoint
    currentTrackingStatus = bridge.trackingStatus;

    /// clear is obsolete except its running in forground
    gpsPoints.clear();
    try {
      gpsPoints.add(gps);
      gpsPoints.addAll(bridge.gpsPoints);

      if (bridge.trackingStatus == TrackingStatus.none) {
        /// app start, no status yet
        bridge.trackingStatus =
            oldTrackingStatus = currentTrackingStatus = TrackingStatus.standing;
      }

      /// remember old status
      oldTrackingStatus = currentTrackingStatus;

      /// prune down to 10 times of gpsPoints needed for one time range calculation
      /// except we are moving
      if (currentTrackingStatus != TrackingStatus.moving) {
        while (gpsPoints.length >
            (Globals.timeRangeTreshold.inSeconds /
                    Globals.trackPointInterval.inSeconds *
                    10)
                .round()) {
          // don't remove the very last.
          // it's required to measure durations
          gpsPoints.removeAt(gpsPoints.length - 2);
        }
      }

      /// filter points for trackpoint calculation
      ///
      calculateSmoothPoints();
      calculateCalcPoints();

      ///
      /// heart of this whole app:
      /// process trackpoint for new status
      ///
      trackPoint();

      /// get a secure calc point if user has triggered status change
      if (calcGpsPoints.isNotEmpty) {
        gps = calcGpsPoints.first;
      } else if (smoothGpsPoints.isNotEmpty) {
        gps = smoothGpsPoints.first;
      } else {
        gps = gps;
      }

      /// if nothing has changed, nothing to do
      if (currentTrackingStatus == oldTrackingStatus) {
        /// if nothing changed simply write data back
      } else {
        if (currentTrackingStatus == TrackingStatus.moving) {
          /// update osm address
          if (Globals.osmLookupCondition == OsmLookup.onStatus) {
            await bridge.setAddress(gps);
          }

          ///
          ///     ---- save event data ---
          ///
          bridge.trackPointGpsStartMoving = gps;
          bridge.trackPointGpslastStatusChange = gps;

          /// save new start moving event
          await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsStartMoving,
              bridge.trackPointGpsStartMoving!);

          /// save general status changed event
          await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsLastStatusChange,
              bridge.trackPointGpsStartMoving!);

          ///
          ///   --- update alias models from cached list ---
          ///
          await ModelAlias.open();
          List<ModelAlias> aliasList = [];

          /// update aliaslist if possible
          try {
            bridge.trackPointGpsStartStanding ??
                (bridge.trackPointAliasIdList = ModelAlias.nextAlias(
                        gps: bridge.trackPointGpsStartStanding!)
                    .map((e) => e.id)
                    .toList());
          } catch (e, stk) {
            logger.error('update cached alias idList: $e', stk);
          }

          /// filter alias list
          for (var id in bridge.trackPointAliasIdList) {
            try {
              ModelAlias model = ModelAlias.getAlias(id);
              if (!model.deleted && model.status != AliasStatus.restricted) {
                aliasList.add(model);
              }
            } catch (e, stk) {
              logger.error('select alias from cached idList: $e', stk);
            }
          }

          ///
          ///     --- insert and update database entrys ---
          ///
          if ((!Globals.statusStandingRequireAlias ||
              (Globals.statusStandingRequireAlias && aliasList.isNotEmpty))) {
            /// create and insert new trackpoint
            ModelTrackPoint newTrackPoint = ModelTrackPoint(
                gps: gps,
                idAlias: bridge.trackPointAliasIdList,
                timeStart: bridge.trackPointGpsStartStanding?.time ??
                    gps.time.subtract(Globals.timeRangeTreshold));
            newTrackPoint.address = bridge.currentAddress;
            newTrackPoint.status = oldTrackingStatus;
            newTrackPoint.timeEnd =
                gpsPoints.first.time.subtract(Globals.trackPointInterval);
            newTrackPoint.idTask = bridge.trackPointTaskIdList;
            newTrackPoint.idUser = bridge.trackPointUserIdList;
            newTrackPoint.notes = bridge.trackPointUserNotes;

            /// insert trackpoint
            await ModelTrackPoint.open();
            await ModelTrackPoint.insert(newTrackPoint);

            /// update alias
            if (aliasList.isNotEmpty) {
              for (var model in aliasList) {
                model.lastVisited = bridge.trackPointGpsStartStanding!.time;
                model.timesVisited++;
              }
              await ModelAlias.write();
            }
          } else {
            logger.log(
                'New trackpoint not saved due to app settings- or alias restrictions');
          }

          ///
        } else if (currentTrackingStatus == TrackingStatus.standing) {
          /// lookup address if wanted
          if (Globals.osmLookupCondition == OsmLookup.onStatus) {
            await bridge.setAddress(gps);
          }

          /// new status is standing
          bridge.trackPointGpsStartStanding = gps;
          bridge.trackPointGpslastStatusChange = gps;

          /// save special events
          await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsStartStanding,
              bridge.trackPointGpsStartStanding!);

          await Cache.setValue<PendingGps>(
              CacheKeys.cacheEventBackgroundGpsLastStatusChange,
              bridge.trackPointGpsStartStanding!);

          ModelAlias.open();
          List<ModelAlias> aliasList = [];

          /// select alias list
          for (ModelAlias model in ModelAlias.nextAlias(gps: gps)) {
            if (model.deleted || model.status == AliasStatus.restricted) {
              // don't add deleted or restricted items
              continue;
            }
            aliasList.add(model);
          }

          /// cache alias id list if wanted
          if (aliasList.isNotEmpty &&
              (!Globals.statusStandingRequireAlias ||
                  (Globals.statusStandingRequireAlias &&
                      aliasList.isNotEmpty))) {
            bridge.trackPointAliasIdList = aliasList.map((e) => e.id).toList();
          }
          await Cache.setValue<List<int>>(CacheKeys.cacheBackgroundAliasIdList,
              bridge.trackPointAliasIdList);

          /// reset user inputs
          await Cache.setValue<List<int>>(
              CacheKeys.cacheBackgroundTaskIdList, []);
          await Cache.setValue<String>(
              CacheKeys.cacheBackgroundTrackPointUserNotes, '');
        }

        /// general cleanup on status change
        gpsPoints.clear();
        gpsPoints.add(gps);
      }

      /// lookup address on every interval
      if (Globals.osmLookupCondition == OsmLookup.always) {
        await bridge.setAddress(gps);
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
    try {
      bridge.trackingStatus = currentTrackingStatus;
      bridge.lastGps = gps;
      bridge.gpsPoints = gpsPoints;
      bridge.calcGpsPoints = calcGpsPoints;
      bridge.smoothGpsPoints = smoothGpsPoints;
    } catch (e, stk) {
      logger.error('load recent trackpoints: $e', stk);
    }

    try {
      /// save status and gpsPoints for next session and foreground live tracking view
      await bridge.saveSession(gps);
    } catch (e, stk) {
      logger.error('save backround finaly; $e', stk);
    }
    // make sure everything is saved
    await DataBridge.reload();
    // wait before shutdown task
    await Future.delayed(const Duration(seconds: 1));
  }

  void calculateSmoothPoints() {
    int smooth = Globals.gpsPointsSmoothCount;
    if (smooth < 2) {
      smoothGpsPoints.addAll(gpsPoints);
      return;
    }
    if (gpsPoints.length <= smooth) {
      return;
    }
    int index = 0;
    while (index <= gpsPoints.length - 1 - smooth) {
      double smoothLat = 0;
      double smoothLon = 0;
      for (var i = 1; i <= smooth; i++) {
        smoothLat += gpsPoints[index + i - 1].lat;
        smoothLon += gpsPoints[index + i - 1].lon;
      }
      smoothLat /= smooth;
      smoothLon /= smooth;
      PendingGps gps = PendingGps(smoothLat, smoothLon);
      if (smoothGpsPoints.isNotEmpty) {
        int m = GPS.distance(gps, smoothGpsPoints.last).round();
        int s = Globals.trackPointInterval.inSeconds;
        double ms = m / s;
        double kmh = ms * 3.6;
        if (kmh > Globals.gpsMaxSpeed) {
          logger.warn('calculate smooth gps with $kmh speed');
        }
      }

      gps.time = gpsPoints[index].time;
      smoothGpsPoints.add(gps);
      index++;
    }
  }

  /// calc points are not added until time range is fulfilled
  void calculateCalcPoints() {
    // get gpsPoints of globals time range
    // to measure movement
    var points = smoothGpsPoints;
    calcGpsPoints.clear();
    if (smoothGpsPoints.length > 1) {
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
        calcGpsPoints.addAll(gpsList);
      }
    }
  }

  void trackPoint() {
    DataBridge bridge = DataBridge.instance;

    /// status change triggered by user
    if ((currentTrackingStatus == TrackingStatus.standing ||
            currentTrackingStatus == TrackingStatus.none) &&
        bridge.statusTriggered) {
      currentTrackingStatus = TrackingStatus.moving;
      bridge.triggerStatusExecuted();
      return;
    }

    /// gps calc points min count
    if (calcGpsPoints.length < 2) {
      return;
    }

    /// check if we started moving
    /// try to calculate how far away we are from last standing point
    if (currentTrackingStatus == TrackingStatus.standing ||
        currentTrackingStatus == TrackingStatus.none) {
      if (GPS.distance(calcGpsPoints.first,
              bridge.trackPointGpsStartMoving ?? calcGpsPoints.last) >
          Globals.distanceTreshold) {
        currentTrackingStatus = TrackingStatus.moving;
      }

      /// check if we stopped moving
      /// using smoothGpsPoints because calcGpsPoints are way too few for calculation
    } else if (currentTrackingStatus == TrackingStatus.moving) {
      if (GPS.distanceOverTrackList(calcGpsPoints) < Globals.distanceTreshold) {
        currentTrackingStatus = TrackingStatus.standing;
      }
    }
  }
}
