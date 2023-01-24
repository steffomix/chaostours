import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared/shared.dart';

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

class RunningTrackPoint {
  final GPS gps;
  DateTime time = DateTime.now();

  RunningTrackPoint(this.gps);

  @override
  String toString() {
    return '${gps.toString()};${time.toIso8601String()}';
  }

  static RunningTrackPoint toModel(String row) {
    List<String> p = row.split(';');
    GPS gps = GPS.toObject(p[0]);
    DateTime time = DateTime.parse(p[1]);
    RunningTrackPoint tp = RunningTrackPoint(gps);
    tp.time = time;
    return tp;
  }
}

class TrackPoint {
  static final Logger logger = Logger.logger<TrackPoint>();

  //static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<RunningTrackPoint> _runningTrackPoints = [];
  // contains all trackpoints during driving (from start to stop)
  static int get length => _runningTrackPoints.length;
  //
  static TrackingStatus _status = TrackingStatus.none;
  static TrackingStatus get status => _status;

  static TrackingStatus _oldStatus = TrackingStatus.none;

  static initializeShared() async {
    logger.log('reset shared data to app start defaults');
    Shared(SharedKeys.activeTrackPointNotes).save('');
    Shared(SharedKeys.activeTrackPointTasks).saveList(<String>[]);
    Shared(SharedKeys.activeTrackPointStatusName)
        .save(TrackingStatus.none.name);
    Shared(SharedKeys.activeTrackpoint).save('');
  }

  static startShared() async {
    /// load model alias for activeTrackpoint

    logger.log('load table alias');
    await ModelAlias.open();
    if (ModelAlias.length < 1) {
      await ModelAlias.openFromAsset();
    }

    /// load recent trackpoints and save to shared
    /// and to provide them to frontend
    logger.log('load recent Trackpoints');
    await ModelTrackPoint.open();
    await Shared(SharedKeys.recentTrackpoints).saveList(
        ModelTrackPoint.recentTrackPoints().map((e) => e.toString()).toList());

    /// load running Trackpoints from shared
    /// convert to objects and inject into class TrackPoint
    logger.log('load running trackpoints');
    _runningTrackPoints.clear();
    _runningTrackPoints.addAll(
        (await Shared(SharedKeys.runningTrackpoints).loadList() ?? [])
            .map((String e) => RunningTrackPoint.toModel(e))
            .toList());

    /// load last tracking Status
    logger.log('load tracking status');
    _status = TrackingStatus.values.byName(
        await Shared(SharedKeys.activeTrackPointStatusName).load() ??
            TrackingStatus.none.name);

    /// remember old status
    _oldStatus = _status;

    /// get gps
    logger.log('lookup GPS');
    GPS gps = await GPS.gps();

    /// start trackpoint calculation process
    logger.log('start trackpoint calculation');
    trackPoint(gps);

    ///
    /// ################### trackpoint executed ###################
    ///
    if (_oldStatus != status) {
      /// load recent trackpoints and save to shared
      /// and to provide them to frontend
      logger.log('load recent Trackpoints');
      await ModelTrackPoint.open();
      Shared(SharedKeys.recentTrackpoints).saveList(
          ModelTrackPoint.recentTrackPoints()
              .map((e) => e.toString())
              .toList());

      /// save new status
      await Shared(SharedKeys.activeTrackPointStatusName).save(status.name);
    }
    await Shared(SharedKeys.runningTrackpoints)
        .saveList(_runningTrackPoints.map((e) => e.toString()).toList());
  }

  static Future<void> trackPoint(GPS gps) async {
    logger.log('processing trackpoint ${gps.toString()}');
    //ModelTrackPoint tp;
    try {
      _runningTrackPoints.add(RunningTrackPoint(gps));

      // min length
      logger.verbose('check running trackpoints min count > 3');
      if (_runningTrackPoints.length < 4) {
        logger.warn(
            'trackpoints min count at ${_runningTrackPoints.length}, skip processing');
        return;
      } else {
        logger.verbose(
            'trackpoints min count at ${_runningTrackPoints.length}, continue processing');
      }

      logger.log('filter running trackpoints for recent time range');
      List<RunningTrackPoint> trackList = _recentTracks();
      // skip if nothing was found
      if (trackList.isEmpty) {
        logger.warn('after filter no trackpoints left, skip processing');
        return;
      } else {
        logger.verbose(
            'filter ${trackList.length} trackpoints, continue processing');
      }
      await _checkStatus(trackList);
    } catch (e, stk) {
      // ignore
      logger.fatal('trackPoint: $e', stk);
    }
  }

  // if tracker is running
  //static bool _tracking = false;
  //static bool get tracking => _tracking;

  static Future<void> _statusChanged(RunningTrackPoint tp) async {
    // create a new TrackPoint as event
    logger.important('Tracking Status changed to #${status.name}');
    logger.log('save new status #${status.name}');
    await Shared(SharedKeys.activeTrackPointStatusName).save(status.toString());

    /// create active trackpoint
    logger.log('create active trackpoint');
    ModelTrackPoint activeTrackPoint = await createModelTrackPoint(tp.gps);

    /// save active trackpoint to database
    //if (_oldStatus == TrackingStatus.standing) {
    logger.log('insert new trackpoint to datatbase table trackpoints');
    await ModelTrackPoint.insert(activeTrackPoint);
    //}

    /// fire event that status has changed
    /// -- to be replaced with more direct! actions
    EventManager.fire<EventOnTrackingStatusChanged>(
        EventOnTrackingStatusChanged(activeTrackPoint));

    /// reset running trackpoints and add current one
    _runningTrackPoints.clear();
    _runningTrackPoints.add(tp);
  }

  static Future<ModelTrackPoint> createModelTrackPoint(GPS gps) async {
    logger.log('create trackpoint event');
    ModelTrackPoint tp = ModelTrackPoint(
        address: Address(gps),
        trackPoints: _runningTrackPoints.map((e) => e.gps).toList(),
        idAlias: ModelAlias.nextAlias(gps).map((e) => e.id).toList(),
        timeStart: _runningTrackPoints.first.time,
        gps: gps);
    tp.status = _oldStatus;
    tp.timeEnd = DateTime.now();
    tp.idTask = (await Shared(SharedKeys.activeTrackPointTasks).loadList())
            ?.map((e) => int.parse(e))
            .toList() ??
        <int>[];
    tp.idAlias = ModelAlias.nextAlias(gps).map((e) => e.id).toList();
    tp.trackPoints = _runningTrackPoints.map((e) => e.gps).toList();
    return tp;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static Future<bool> _checkStatus(List<RunningTrackPoint> trackList) async {
    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (_checkMoved(trackList)) {
        // use the most recent Trackpoint as reference
        await _statusChanged(trackList.first);
        _oldStatus = status;
        _status = TrackingStatus.moving;
        return true;
      }
    } else {
      if (_checkStopped(trackList)) {
        // use the one before oldest trackpoint where we stopped as reference
        await _statusChanged(trackList.last);
        _oldStatus = status;
        _status = TrackingStatus.standing;
        return true;
      }
    }
    logger.log('No Status change detected, still Status #${status.name}');
    return false;
  }

  static bool _checkMoved(List<RunningTrackPoint> tl) {
    // check if moved
    double dist = 0;
    RunningTrackPoint tRef = tl.last;
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i].gps, tRef.gps);
      if (dist > Globals.distanceTreshold) {
        return true;
      }
    }
    return false;
  }

  static bool _checkStopped(List<RunningTrackPoint> tl) {
    double dist = 0;
    double distMoved = 0;
    RunningTrackPoint tRef = tl.first;
    // check if stopped
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i].gps, tRef.gps);
      if (dist > distMoved) distMoved = dist;
    }
    logger.verbose('moved: $distMoved in ${tl.length} tracks');
    if (distMoved < Globals.distanceTreshold) {
      return true;
    }
    return false;
  }

  /// collect recent Trackpoints in backwards order since last status changed
  /// and until <timeTreshold>
  /// so that trackList[0] is most recent
  static List<RunningTrackPoint> _recentTracks() {
    List<RunningTrackPoint> trackList = [];
    DateTime treshold = DateTime.now().subtract(Globals.stopTimeTreshold);
    bool outDated;
    for (var i = _runningTrackPoints.length - 1; i >= 0; i--) {
      outDated = _runningTrackPoints[i].time.isBefore(treshold);
      if (outDated) break;
      trackList.add(_runningTrackPoints[i]);
    }
    return trackList;
  }

  ///
  ///
  /// ################### tools ################
  ///
  ///
  ///

  static String timeElapsed() {
    if (_runningTrackPoints.isEmpty) return '00:00:00';
    return util.timeElapsed(
        _runningTrackPoints.first.time, _runningTrackPoints.last.time);
  }

  static double distance() {
    if (_runningTrackPoints.isEmpty) return 0.0;
    double dist;
    if (_status == TrackingStatus.standing) {
      dist = GPS.distance(
          _runningTrackPoints.first.gps, _runningTrackPoints.last.gps);
    } else {
      dist = movedDistance(_runningTrackPoints);
    }
    return (dist * 1000).round() / 1000;
  }

  // calc distance over multiple trackpoints in meters
  static double movedDistance(List<RunningTrackPoint> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS gps = tracklist[0].gps;
    for (var i = 1; i < tracklist.length; i++) {
      dist += GPS.distance(gps, tracklist[i].gps);
      gps = tracklist[i].gps;
    }
    return dist;
  }
}
