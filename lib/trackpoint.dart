import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared/shared.dart';
import 'package:chaostours/shared/shared_data.dart';

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
  static final Logger logger = Logger.logger<TrackPoint>();

  //static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<GPS> _runningTrackPoints = [];
  // contains all trackpoints during driving (from start to stop)
  static int get length => _runningTrackPoints.length;
  //
  static TrackingStatus _status = TrackingStatus.none;
  static TrackingStatus get status => _status;

  static TrackingStatus _oldStatus = TrackingStatus.none;

  static ModelTrackPoint? _activeTrackPoint;

  static startShared() async {
    await _beforeSharedTrackPoint();
    GPS gps = await GPS.gps();
    await trackPoint(gps);
    await _afterSharedTrackPoint();
  }

  /// load last trackpoint results
  static Future<void> _beforeSharedTrackPoint() async {
    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String>? sharedList = await shared.loadList() ?? [];
    if (sharedList.isEmpty) {
      _status = TrackingStatus.standing;
      _runningTrackPoints.clear();
    } else {
      try {
        _status = TrackingStatus.values.byName(sharedList[0]);
      } catch (e) {
        logger.error(
            '"${sharedList[0]}" is not a valid TrackingStatu. Default to "standing"',
            null);
        _status = TrackingStatus.standing;
      }
      if (sharedList.length > 1) {
        // remove status
        sharedList.removeAt(0);
        for (var row in sharedList) {
          try {
            _runningTrackPoints.add(GPS.toSharedObject(row));
          } catch (e) {
            logger.error('"$row" is not valid shared GPS Data', null);
          }
        }
      }
    }
  }

  static Future<void> _afterSharedTrackPoint() async {
    if (_runningTrackPoints.isEmpty) {
      throw 'no runningTrackpoint found';
    }
    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String> sharedList = [_status.name];
    for (var tp in _runningTrackPoints) {
      sharedList.add(tp.toSharedString());
    }
    shared.saveList(sharedList);
  }

  static Future<void> trackPoint(GPS gps) async {
    logger.log('processing trackpoint ${gps.toString()}');
    //ModelTrackPoint tp;
    try {
      logger.log('create running trackpoint');
      _runningTrackPoints.add(gps);
      while (_runningTrackPoints.length > 300) {
        _runningTrackPoints.removeAt(0);
      }

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
      List<GPS> trackList = _recentTracks();
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

  static Future<void> _statusChanged(GPS tp) async {
    // create a new TrackPoint as event
    await logger.important('Tracking Status changed to #${status.name}');
    await logger.log('save new status #${status.name}');
    //await Shared(SharedKeys.activeTrackPointStatusName).save(status.toString());

    /// create active trackpoint
    await logger.log('create active trackpoint');
    _activeTrackPoint = await createModelTrackPoint(tp);

    /// save active trackpoint to database
    //if (_oldStatus == TrackingStatus.standing) {
    await logger.log('insert new trackpoint to datatbase table trackpoints');
    await ModelTrackPoint.insert(_activeTrackPoint!);
    await ModelTrackPoint.open();
    //}

    /// fire event that status has changed
    /// -- to be replaced with more direct! actions
    await EventManager.fire<EventOnTrackingStatusChanged>(
        EventOnTrackingStatusChanged(_activeTrackPoint!));

    /// reset running trackpoints and add current one
    _runningTrackPoints.clear();
    _runningTrackPoints.add(tp);
    await logger.log('processing trackpoint finished');
  }

  static Future<ModelTrackPoint> createModelTrackPoint([GPS? gps]) async {
    if (gps == null) {
      await logger.warn('no gps on trackpoint. lookup foreground gps');
    }
    gps ??= await GPS.gps();
    await logger.log('create trackpoint event');
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        address: Address(gps),
        trackPoints: _runningTrackPoints.map((e) => e).toList(),
        idAlias: <int>[],
        timeStart: _runningTrackPoints.first.time);
    tp.status = _status;
    tp.timeEnd = DateTime.now();
    tp.idTask = <int>[];
    return tp;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static Future<bool> _checkStatus(List<GPS> trackList) async {
    if (_runningTrackPoints.length > 1) {
      _oldStatus = _status;
      _status =
          _status == TrackingStatus.standing || _status == TrackingStatus.none
              ? TrackingStatus.moving
              : TrackingStatus.standing;
      return true;
    }
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
    await logger.log('No Status change detected, still Status #${status.name}');

    await logger.log('processing trackpoint finished');
    return false;
  }

  static bool _checkMoved(List<GPS> tl) {
    // check if moved
    double dist = 0;
    GPS tRef = tl.last;
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i], tRef);
      if (dist > Globals.distanceTreshold) {
        return true;
      }
    }
    return false;
  }

  static bool _checkStopped(List<GPS> tl) {
    double dist = 0;
    double distMoved = 0;
    GPS tRef = tl.first;
    // check if stopped
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i], tRef);
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
  static List<GPS> _recentTracks() {
    List<GPS> trackList = [];
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
      dist = GPS.distance(_runningTrackPoints.first, _runningTrackPoints.last);
    } else {
      dist = movedDistance(_runningTrackPoints);
    }
    return (dist * 1000).round() / 1000;
  }

  // calc distance over multiple trackpoints in meters
  static double movedDistance(List<GPS> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS gps = tracklist[0];
    for (var i = 1; i < tracklist.length; i++) {
      dist += GPS.distance(gps, tracklist[i]);
      gps = tracklist[i];
    }
    return dist;
  }
}
