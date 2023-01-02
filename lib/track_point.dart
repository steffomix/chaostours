import 'package:chaostours/config.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/util.dart' as util;

class TrackPoint {
  //static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<ModelTrackPoint> _trackPoints = [];
  // contains all trackpoints during driving (from start to stop)

  //
  static TrackingStatus _status = TrackingStatus.none;
  static TrackingStatus get status => _status;
  static DateTime _lastStatusChange = DateTime.now();

  // if tracker is running
  static bool _tracking = false;
  static bool get tracking => _tracking;

  static String timeElapsed() {
    if (_trackPoints.isEmpty) return '00:00:00';
    return util.timeElapsed(
        _trackPoints.first.timeStart, _trackPoints.last.timeStart);
  }

  static double distance() {
    if (_trackPoints.isEmpty) return 0.0;
    if (_status == TrackingStatus.standing) {
      return (GPS.distance(_trackPoints.first.gps, _trackPoints.last.gps) *
                  1000)
              .round() /
          1000;
    } else {
      return movedDistance(_trackPoints);
    }
  }

  /*
  final int _id = ++_nextId;
  final GPS _gps;
  final DateTime _time = DateTime.now();
  List<ModelAlias> _alias = [];

  int get id => _id;
  GPS get gps => _gps;
  DateTime get time => _time;
  List<ModelAlias> get alias => _alias;
  late Address address;
*/
  TrackPoint() {
    throw 'Do not instantiate TrackPoint, use ModelTrackPoint!';
  }

  static void _statusChanged(ModelTrackPoint tp) async {
    // create a new TrackPoint as event
    ModelTrackPoint event = await createEvent();
    if (_status == TrackingStatus.standing) {
      await ModelTrackPoint.insert(event);
    }
    eventBusTrackingStatusChanged.fire(event);
    _trackPoints.clear();
    _trackPoints.add(tp);
    _lastStatusChange = DateTime.now();
  }

  static Future<ModelTrackPoint> createEvent() async {
    ModelTrackPoint event = await create();
    event.status = _status;
    event.timeStart = _trackPoints.first.timeStart;
    event.timeEnd = DateTime.now();
    event.trackPoints = [..._trackPoints];
    return event;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static void _checkStatus(ModelTrackPoint tp) {
    // wait after status changed
    if (_lastStatusChange
        .add(AppConfig.waitTimeAfterStatusChanged)
        .isAfter(DateTime.now())) {
      return;
    }
    // min length
    if (_trackPoints.length < 4) return;

    List<ModelTrackPoint> trackList = _recentTracks();
    // skip if nothing was found
    if (trackList.isEmpty) return;

    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (_checkMoved(trackList)) {
        // use the most recent Trackpoint as reference
        _statusChanged(trackList.first);
        _status = TrackingStatus.moving;
        return;
      }
    } else {
      if (_checkStopped(trackList)) {
        // use the one before oldest trackpoint where we stopped as reference
        _statusChanged(trackList.last);
        _status = TrackingStatus.standing;
        return;
      }
    }
  }

  static bool _checkMoved(List<ModelTrackPoint> tl) {
    // check if moved
    double dist = 0;
    ModelTrackPoint tRef = tl.last;
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i].gps, tRef.gps);
      if (dist > AppConfig.distanceTreshold) {
        return true;
      }
    }
    return false;
  }

  static bool _checkStopped(List<ModelTrackPoint> tl) {
    double dist = 0;
    double distMoved = 0;
    ModelTrackPoint tRef = tl.first;
    // check if stopped
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i].gps, tRef.gps);
      if (dist > distMoved) distMoved = dist;
    }
    logVerbose('moved: $distMoved in ${tl.length} tracks');
    if (distMoved < AppConfig.distanceTreshold) {
      return true;
    }
    return false;
  }

  /// collect recent Trackpoints in backwards order since last status changed
  /// and until <timeTreshold>
  /// so that trackList[0] is most recent
  static List<ModelTrackPoint> _recentTracks() {
    List<ModelTrackPoint> trackList = [];
    DateTime treshold = DateTime.now().subtract(AppConfig.stopTimeTreshold);
    bool outDated;
    for (var i = _trackPoints.length - 1; i >= 0; i--) {
      outDated = _trackPoints[i].timeStart.isBefore(treshold);
      if (outDated) break;
      trackList.add(_trackPoints[i]);
    }
    return trackList;
  }

  // calc distance over multiple trackpoints in meters
  static double movedDistance(List<ModelTrackPoint> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS gps = tracklist[0].gps;
    for (var i = 1; i < tracklist.length; i++) {
      dist += GPS.distance(gps, tracklist[i].gps);
      gps = tracklist[i].gps;
    }
    return dist;
  }

  static Future<ModelTrackPoint> create() async {
    GPS gps = await GPS.gps();
    Address address = Address(gps);
    if (AppConfig.alwaysLookupAddress) await address.lookupAddress();

    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: <ModelTrackPoint>[],
        idAlias: ModelAlias.nextAlias(gps).map((e) => e.id).toList(),
        timeStart: DateTime.now(),
        address: address);

    return tp;
  }

  /// tracking heartbeat with <trackingTickTime> speed
  static void _track([bool first = false]) async {
    if (!_tracking) return;
    Future.delayed(AppConfig.trackPointTickTime, () async {
      ModelTrackPoint tp;
      try {
        tp = await create();
        tp.status = _status;
        _trackPoints.add(tp);
        if (first) {
          tp = await createEvent();
          tp.timeEnd = DateTime.now();
          _status = TrackingStatus.standing;
          eventBusTrackingStatusChanged.fire(await createEvent());
        } else {
          _checkStatus(tp);
          eventBusTrackPointCreated.fire(tp);
        }
      } catch (e, stk) {
        // ignore
        logFatal('TrackPoint::create', e, stk);
      }
      _track();
    });
  }

  /// start tracking heartbeat
  static void startTracking() async {
    if (_tracking) return;
    await TrackPoint.create();
    logInfo('start tracking');
    _tracking = true;
    _track(true);
  }

  /// stop tracking heartbeat
  static void stopTracking() {
    if (!_tracking) return;
    logInfo('stop tracking');
    _tracking = false;
  }
}
