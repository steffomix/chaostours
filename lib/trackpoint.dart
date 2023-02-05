import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/util.dart' as util;
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
  final Logger logger = Logger.logger<TrackPoint>();

  static TrackPoint? _instance;
  TrackPoint._();
  factory TrackPoint() => _instance ??= TrackPoint._();

  /// int _nextId = 0;
  /// contains all trackpoints from current state start or stop
  final List<GPS> gpsPoints = [];

  ///
  TrackingStatus _status = TrackingStatus.none;
  TrackingStatus get status => _status;

  Future<void> startShared() async {
    await _beforeSharedTrackPoint();
    GPS gps = await GPS.gps();
    await trackPoint(gps);
    await _afterSharedTrackPoint();
  }

  /// load last trackpoint results
  Future<void> _beforeSharedTrackPoint() async {
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

  Future<void> _afterSharedTrackPoint() async {
    if (gpsPoints.isEmpty) {
      throw 'no runningTrackpoint found';
    }
    Shared shared = Shared(SharedKeys.trackPointUp);
    List<String> sharedList = [_status.name];
    var g = gpsPoints;
    for (var gps in gpsPoints) {
      sharedList.add(gps.toSharedString());
    }
    shared.saveList(sharedList);
  }

  Future<void> trackPoint(GPS gps) async {
    if (gpsPoints.length > 10) {
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

  Future<void> _statusChanged(GPS gps) async {
    // create a new TrackPoint as event
    await logger.important('Tracking Status changed to #${status.name}');
    await logger.log('save new status #${status.name}');
    //await Shared(SharedKeys.activeTrackPointStatusName).save(status.toString());

    /// create active trackpoint
    await logger.log('create active trackpoint');
    ModelTrackPoint newEntry = await createModelTrackPoint(gps);

    /// save active trackpoint to database
    //if (_oldStatus == TrackingStatus.standing) {
    await logger.log('insert new trackpoint to database');
    await ModelTrackPoint.insert(newEntry);
    await ModelTrackPoint.open();
    //}

    /// reset running trackpoints and add current one
    gpsPoints.clear();
    gpsPoints.add(gps);
    await logger.log('processing trackpoint finished');
  }

  Future<ModelTrackPoint> createModelTrackPoint([GPS? gps]) async {
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
      String? tpRow = await shared.loadString();
      if (tpRow == null) {
        logger.warn('no trackPoint Data found in SharedKeys.trackPointDown');
      } else {
        ModelTrackPoint tps = ModelTrackPoint.toSharedModel(tpRow);
        notes = tps.notes;
        idTask = tps.idTask;
        idAlias = tps.idAlias;

        /// reset user input and save back to shared
        /*
        tps.notes = '';
        tps.idTask = <int>[];
        tps.idAlias = <int>[];
        await shared.saveString(tps.toSharedString());
        */
      }
    } catch (e, stk) {
      logger.error('load shared data for trackPoint: ${e.toString()}', stk);
    }
    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: gpsPoints.map((e) => e).toList(),
        idAlias: idAlias,
        timeStart: gpsPoints.last.time);
    tp.status = _status;
    tp.timeEnd = DateTime.now();
    tp.idTask = idTask;
    tp.notes = notes;
    return tp;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  Future<bool> _checkStatus(List<GPS> gpsList) async {
    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (_checkMoved(gpsList)) {
        // use the most recent Trackpoint as reference
        await _statusChanged(gpsList.first);
        _status = TrackingStatus.moving;
        return true;
      }
    } else {
      if (_checkStopped(gpsList)) {
        // use the one before oldest trackpoint where we stopped as reference
        await _statusChanged(gpsList.last);
        _status = TrackingStatus.standing;
        return true;
      }
    }
    await logger.log('No Status change detected, still Status #${status.name}');

    await logger.log('processing trackpoint finished');
    return false;
  }

  bool _checkMoved(List<GPS> gpsList) {
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

  bool _checkStopped(List<GPS> gpsList) {
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
  List<GPS> _recentTracks() {
    List<GPS> gpsList = [];
    DateTime treshold = DateTime.now().subtract(Globals.stopTimeTreshold);
    for (var gps in gpsPoints) {
      if (gps.time.isAfter(treshold)) {
        gpsList.add(gps);
      } else {
        break;
      }
    }
    return gpsList;
  }

  ///
  ///
  /// ################### tools ################
  ///
  ///
  ///

  String timeElapsed() {
    if (gpsPoints.isEmpty) return '00:00:00';
    return util.timeElapsed(gpsPoints.last.time, gpsPoints.first.time);
  }

  double distance() {
    if (gpsPoints.isEmpty) return 0.0;
    double dist;
    if (_status == TrackingStatus.standing) {
      dist = GPS.distance(gpsPoints.last, gpsPoints.first);
    } else {
      dist = movedDistance(gpsPoints);
    }
    return (dist * 1000).round() / 1000;
  }

  // calc distance over multiple trackpoints in meters
  double movedDistance(List<GPS> tracklist) {
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
