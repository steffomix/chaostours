import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart'; // for read only
import 'package:chaostours/logger.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/file_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrackingStatus {
  none(0),
  standing(1),
  moving(2);

  final int value;
  const TrackingStatus(this.value);

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
    // init dataBridge
    DataBridge bridge = DataBridge.instance;
    // reload shared preferences
    await DataBridge.reload();
    // load global settings
    await Globals.loadSettings();

    /// create gpsPoint
    PendingGps gps = PendingGps(lat, lon);
    GPS.lastGps = gps;
    // if not yet set, do it right now
    bridge.gpsStartMoving ??= gps;
    bridge.gpsStartStanding ??= gps;

    // load last session data
    await bridge.loadBackground(gps);

    /// load foreground data and user inputs
    await bridge.loadForeground(gps);

    /// update trackpoints edited by user
    try {
      for (var row in bridge.trackPointUpdates) {
        await ModelTrackPoint.update(row);
      }
      bridge.trackPointUpdates.clear();
    } catch (e, stk) {
      logger.error('update trackpoints: ${e.toString()}', stk);
    }

    /// all foreground tasks are done - save to disk
    await bridge.saveForeground(gps);

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

      /// save 10 times of gpsPoints needed for one time range calculation
      while (gpsPoints.length >
          (Globals.timeRangeTreshold.inSeconds /
                  Globals.trackPointInterval.inSeconds *
                  10)
              .round()) {
        // don't remove the very last.
        // it's required to measure durations
        gpsPoints.removeAt(gpsPoints.length - 2);
      }

      /// filter points for trackpoint calculation
      ///
      calculateSmoothPoints();
      calculateCalcPoints();

      /// secureCalcPoint may be needed if user triggers status moving
      /// and no calc points are yet available
      PendingGps secureCalcPoint;
      if (calcGpsPoints.isNotEmpty) {
        secureCalcPoint = calcGpsPoints.first;
      } else if (smoothGpsPoints.isNotEmpty) {
        secureCalcPoint = smoothGpsPoints.first;
      } else {
        secureCalcPoint = gps;
      }

      ///
      /// heart of this whole app:
      /// process trackpoint for new status
      ///
      trackPoint();

      /// if nothing has changed, nothing to do
      if (currentTrackingStatus == oldTrackingStatus) {
        /// if nothing changed simply write data back
      } else {
        /// else if status has changed we will need ModelAlias
        await ModelAlias.open();

        /// status has changed to _status.
        /// if we are now moving, we need to save the gpsPoint where
        /// standing was detected, which is the last one in the list.
        if (currentTrackingStatus == TrackingStatus.moving) {
          ModelTrackPoint newEntry = await createModelTrackPoint();
          await ModelTrackPoint.insert(newEntry);

          /// write alias info into cached found alias
          for (var item
              in bridge.aliasIdList.map((id) => ModelAlias.getAlias(id))) {
            if (!item.deleted) {
              item.lastVisited = DateTime.now();
              item.timesVisited++;
            }
          }
          await ModelAlias.write();

          /// reset data
          bridge.gpsStartMoving = gps;
          bridge.aliasIdList = [];
          bridge.taskIdList = [];
          bridge.userIdList = [];
          bridge.trackPointUserNotes = '';

          /// new status is standing
          /// remember address from detecting standing
          /// to be used in createModelTrackPoint on next status change
          if (Globals.osmLookupCondition != OsmLookup.never) {
            await lookupAddress(gps);
          }
        } else {
          /// new status is standing
          /// Tasks for this event:
          /// - cache address if allowed
          /// - cache gps point "gpsStartStanding" and time standing started
          /// - cache alias ids
          if (Globals.osmLookupCondition == OsmLookup.onStatus) {
            await lookupAddress(gps);
          }
          bridge.gpsStartStanding = gps;
          await bridge.updateAliasIdList(secureCalcPoint);
        }

        /// reset gpspoints
        gpsPoints.clear();
        gpsPoints.add(gps);
      }
      if (Globals.osmLookupCondition == OsmLookup.always) {
        await lookupAddress(gps);
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
    try {
      bridge.gpsPoints = gpsPoints;
      bridge.calcGpsPoints = calcGpsPoints;
      bridge.smoothGpsPoints = smoothGpsPoints;
      bridge.lastGps = gps;
      bridge.trackingStatus = currentTrackingStatus;
      bridge.recentTrackPoints = ModelTrackPoint.recentTrackPoints();
      bridge.lastVisitedTrackPoints = ModelTrackPoint.lastVisited(gps);
      bridge.triggerStatusExecuted();
    } catch (e, stk) {
      logger.error('load recent trackpoints: $e', stk);
    }

    try {
      /// save status and gpsPoints for next session and foreground live tracking view
      await bridge.saveBackground(gps);
    } catch (e, stk) {
      logger.error('save backround finaly; $e', stk);
    }
    var inst = await SharedPreferences.getInstance();
    // make sure everything is saved
    await inst.reload();
    // wait before shutdown task
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> lookupAddress(PendingGps gps) async {
    try {
      DataBridge.instance.address =
          (await Address(gps).lookupAddress()).toString();
    } catch (e, stk) {
      DataBridge.instance.address = '';
      logger.error('lookup address: $e', stk);
    }
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
              bridge.gpsStartMoving ?? calcGpsPoints.last) >
          Globals.distanceTreshold) {
        currentTrackingStatus = TrackingStatus.moving;
      }

      /// check if we stopped moving
      /// using smoothGpsPoints because calcGpsPoints are way too few for calculation
    } else if (currentTrackingStatus == TrackingStatus.moving) {
      if (GPS.distanceoverTrackList(calcGpsPoints) < Globals.distanceTreshold) {
        currentTrackingStatus = TrackingStatus.standing;
      }
    }
  }

  Future<ModelTrackPoint> createModelTrackPoint() async {
    DataBridge bridge = DataBridge.instance;
    GPS gps = bridge.gpsStartStanding!;
    await logger.log('create new ModelTrackPoint');
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: gpsPoints.map((e) => e).toList(),
        idAlias: bridge.aliasIdList,
        timeStart: DataBridge.instance.gpsStartMoving?.time ?? gps.time);
    tp.address = DataBridge.instance.address; // should be loaded at this point
    tp.status = oldTrackingStatus;
    tp.timeEnd = calcGpsPoints.first.time;
    tp.idTask = bridge.taskIdList;
    tp.idUser = bridge.userIdList;
    tp.notes = bridge.trackPointUserNotes;
    return tp;
  }
}
