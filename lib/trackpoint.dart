import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
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

class TrackPoint {
  static final Logger logger = Logger.logger<TrackPoint>();

  //static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<GPS> gpsPoints = [];
  // contains all trackpoints during driving (from start to stop)
  static int get length => gpsPoints.length;
  //
  static TrackingStatus _status = TrackingStatus.none;
  static TrackingStatus get status => _status;

  static TrackingStatus _oldStatus = TrackingStatus.none;

  static ModelTrackPoint? _activeTrackPoint;

  static Future<void> startShared() async {
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
      gpsPoints.clear();
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
            gpsPoints.add(GPS.toSharedObject(row));
          } catch (e) {
            logger.error('"$row" is not valid shared GPS Data', null);
          }
        }
      }
    }
  }

  static Future<void> _afterSharedTrackPoint() async {
    if (gpsPoints.isEmpty) {
      throw 'no runningTrackpoint found';
    }
    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String> sharedList = [_status.name];
    for (var tp in gpsPoints) {
      sharedList.add(tp.toSharedString());
    }
    shared.saveList(sharedList);
  }

  static Future<void> trackPoint(GPS gps) async {
    if (gpsPoints.length > 3) {
      _oldStatus = _status;
      _status =
          _status == TrackingStatus.standing || _status == TrackingStatus.none
              ? TrackingStatus.moving
              : TrackingStatus.standing;
      _statusChanged(gps);
      return;
    }
    logger.log('processing trackpoint ${gps.toString()}');
    //ModelTrackPoint tp;
    try {
      gpsPoints.insert(0, gps);
      while (gpsPoints.length > 300) {
        gpsPoints.removeLast();
      }

      if (gpsPoints.length < 4) {
        return;
      }

      List<GPS> gpsList = _recentTracks();
      // skip if nothing was found
      if (gpsList.isEmpty) {
        return;
      } else {
        logger.verbose(
            'filter ${gpsList.length} trackpoints, continue processing');
      }
      await _checkStatus(gpsList);
    } catch (e, stk) {
      // ignore
      logger.fatal('trackPoint: $e', stk);
    }
  }

  static Future<void> _statusChanged(GPS gps) async {
    // create a new TrackPoint as event
    await logger.important('Tracking Status changed to #${status.name}');
    await logger.log('save new status #${status.name}');
    //await Shared(SharedKeys.activeTrackPointStatusName).save(status.toString());

    /// create active trackpoint
    await logger.log('create active trackpoint');
    ModelTrackPoint newEntry = await createModelTrackPoint(gps);
    _activeTrackPoint = newEntry;

    /// save active trackpoint to database
    //if (_oldStatus == TrackingStatus.standing) {
    await logger.log('insert new trackpoint to datatbase table trackpoints');
    await ModelTrackPoint.insert(newEntry);
    await ModelTrackPoint.open();
    //}

    /// reset running trackpoints and add current one
    gpsPoints.clear();
    gpsPoints.add(gps);
    await logger.log('processing trackpoint finished');
  }

  static Future<ModelTrackPoint> createModelTrackPoint([GPS? gps]) async {
    if (gps == null) {
      await logger.warn('no gps on trackpoint. lookup foreground gps');
    }
    gps ??= await GPS.gps();
    await logger.log('create new ModelTrackPoint');
    String notes = '';
    List<int> idTask = [];
    List<int> idAlias = [];

    try {
      /// load user inputs
      Shared shared = Shared(SharedKeys.trackPointDown);
      ModelTrackPoint tps =
          ModelTrackPoint.toSharedModel(await shared.loadString() ?? '');
      notes = tps.notes;
      idTask = tps.idTask;
      idAlias = tps.idAlias;

      /// reset user input and save back to shared
      tps.notes = '';
      tps.idTask = <int>[];
      tps.idAlias = <int>[];
      await shared.saveString(tps.toSharedString());
    } catch (e, stk) {
      logger.error('load shared data for trackPoint: ${e.toString()}', stk);
    }
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        address: Address(gps),
        trackPoints: gpsPoints.map((e) => e).toList(),
        idAlias: idAlias,
        timeStart: gpsPoints.first.time);
    tp.status = _status;
    tp.timeEnd = DateTime.now();
    tp.idTask = idTask;
    tp.notes = notes;
    return tp;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static Future<bool> _checkStatus(List<GPS> gpsList) async {
    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (_checkMoved(gpsList)) {
        // use the most recent Trackpoint as reference
        await _statusChanged(gpsList.first);
        _oldStatus = status;
        _status = TrackingStatus.moving;
        return true;
      }
    } else {
      if (_checkStopped(gpsList)) {
        // use the one before oldest trackpoint where we stopped as reference
        await _statusChanged(gpsList.last);
        _oldStatus = status;
        _status = TrackingStatus.standing;
        return true;
      }
    }
    await logger.log('No Status change detected, still Status #${status.name}');

    await logger.log('processing trackpoint finished');
    return false;
  }

  static bool _checkMoved(List<GPS> gpsList) {
    // check if moved
    double dist = 0;
    GPS tRef = gpsList.last;
    for (var i = 0; i < gpsList.length; i++) {
      dist = GPS.distance(gpsList[i], tRef);
      if (dist > Globals.distanceTreshold) {
        return true;
      }
    }
    return false;
  }

  static bool _checkStopped(List<GPS> gpsList) {
    double dist = 0;
    double distMoved = 0;
    GPS tRef = gpsList.first;
    // check if stopped
    for (var i = 0; i < gpsList.length; i++) {
      dist = GPS.distance(gpsList[i], tRef);
      if (dist > distMoved) distMoved = dist;
    }
    logger.verbose('moved: $distMoved in ${gpsList.length} tracks');
    if (distMoved < Globals.distanceTreshold) {
      return true;
    }
    return false;
  }

  /// collect recent Trackpoints since last status changed
  /// and until <timeTreshold>
  /// so that gpsList[0] is most recent
  static List<GPS> _recentTracks() {
    List<GPS> gpsList = [];
    DateTime treshold = DateTime.now().subtract(Globals.stopTimeTreshold);
    bool outDated;
    for (var i = 0; i < gpsPoints.length; i++) {
      outDated = gpsPoints[i].time.isBefore(treshold);
      if (outDated) break;
      gpsList.add(gpsPoints[i]);
    }
    return gpsList;
  }

  ///
  ///
  /// ################### tools ################
  ///
  ///
  ///

  static String timeElapsed() {
    if (gpsPoints.isEmpty) return '00:00:00';
    return util.timeElapsed(gpsPoints.first.time, gpsPoints.last.time);
  }

  static double distance() {
    if (gpsPoints.isEmpty) return 0.0;
    double dist;
    if (_status == TrackingStatus.standing) {
      dist = GPS.distance(gpsPoints.first, gpsPoints.last);
    } else {
      dist = movedDistance(gpsPoints);
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
