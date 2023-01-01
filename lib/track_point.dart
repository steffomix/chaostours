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

class TrackPoint {
  static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<TrackPoint> _trackPoints = [];
  // contains all trackpoints during driving (from start to stop)

  //
  static TrackingStatus _status = TrackingStatus.standing;
  static TrackingStatus get status => _status;
  static DateTime _lastStatusChange = DateTime.now();

  // if tracker is running
  static bool _tracking = false;
  static bool get tracking => _tracking;

  final int _id = ++_nextId;
  final GPS _gps;
  final DateTime _time = DateTime.now();
  List<ModelAlias> _alias = [];

  int get id => _id;
  GPS get gps => _gps;
  DateTime get time => _time;
  List<ModelAlias> get alias => _alias;
  late Address address;

  TrackPoint(this._gps) {
    _trackPoints.add(this);
  }

  static void _statusChanged(TrackPoint tp) async {
    _status = _status == TrackingStatus.moving
        ? TrackingStatus.standing
        : TrackingStatus.moving;
    TrackPointEvent event = createEvent(tp: tp, newStatus: true);
    // latest point of time to save event to disk
    if (_status == TrackingStatus.moving) {
      // we just started moving
      _status = TrackingStatus.standing;
      event.timeEnd = tp.time;
      // if not already saved
      if (event.id <= 0) {
        await ModelTrackPoint.insert(event);
        event.model = event;
      } else {
        ModelTrackPoint.update(event);
      }
    }
    eventBusTrackingStatusChanged.fire(event);
    _trackPoints.clear();
    _trackPoints.add(tp);
  }

  static TrackPointEvent createEvent(
      {required TrackPoint tp, bool newStatus = false}) {
    TrackPointEvent mtp = TrackPointEvent(
        status: _status,
        address: tp.address,
        trackList: _trackPoints.isEmpty
            ? <TrackPoint>[tp]
            : <TrackPoint>[..._trackPoints],
        lat: tp.gps.lat,
        lon: tp.gps.lon,
        timeStart: _trackPoints.first.time,
        timeEnd: _trackPoints.last.time,
        idAlias: tp.alias.map((ModelAlias m) {
          return m.id;
        }).toList());
    if (newStatus) mtp.statusChanged();
    return mtp;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static void _checkStatus(TrackPoint tp) {
    // wait after status changed
    if (_lastStatusChange
        .add(AppConfig.waitTimeAfterStatusChanged)
        .isAfter(DateTime.now())) {
      return;
    }
    // min length
    if (_trackPoints.length < 4) return;

    List<TrackPoint> trackList = _recentTracks();
    // skip if nothing was found
    if (trackList.isEmpty) return;

    if (_status == TrackingStatus.standing) {
      if (_checkMoved(trackList)) {
        // use the most recent Trackpoint as reference
        _statusChanged(trackList.first);
        return;
      }
    } else {
      if (_checkStopped(trackList)) {
        // use the one before oldest trackpoint where we stopped as reference
        _statusChanged(trackList.last);
        return;
      }
    }
  }

  static bool _checkMoved(List<TrackPoint> tl) {
    // check if moved
    double dist = 0;
    TrackPoint tRef = tl.last;
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i]._gps, tRef._gps);
      if (dist > AppConfig.distanceTreshold) {
        return true;
      }
    }
    return false;
  }

  static bool _checkStopped(List<TrackPoint> tl) {
    double dist = 0;
    double distMoved = 0;
    TrackPoint tRef = tl.first;
    // check if stopped
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i]._gps, tRef._gps);
      if (dist > distMoved) distMoved = dist;
    }
    logVerbose('moved: $distMoved in ${tl.length} tracks');
    if (distMoved < AppConfig.distanceTreshold) {
      return true;
    }
    return false;
  }

  /// collect recent Trackpoints in backwards order since last status changed with gpsOk
  /// so that trackList[0] is most recent
  static List<TrackPoint> _recentTracks() {
    // collect TrackPoints of last <timeTreshold> with <gpsOk>
    List<TrackPoint> trackList = [];
    List<int> ids = [];
    DateTime treshold = DateTime.now().subtract(AppConfig.stopTimeTreshold);
    bool outDated;
    for (var i = _trackPoints.length - 1; i >= 0; i--) {
      outDated = _trackPoints[i].time.isBefore(treshold);
      if (outDated) break;
      trackList.add(_trackPoints[i]);
      ids.add(_trackPoints[i].id);
    }
    return trackList;
  }

  // calc distance in meters
  static double movedDistance(List<TrackPoint> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS gps = tracklist[0]._gps;
    for (var i = 1; i < tracklist.length; i++) {
      dist += GPS.distance(gps, tracklist[i]._gps);
      gps = tracklist[i]._gps;
    }
    return dist;
  }

  static Future<TrackPoint> create() async {
    GPS gps = await GPS.gps();

    TrackPoint tp = TrackPoint(gps);

    tp.address = Address(gps);
    //await tp.address.lookupAddress();
    tp._alias = ModelAlias.nextAlias(gps);

    return tp;
  }

  /// tracking heartbeat with <trackingTickTime> speed
  static void _track([bool first = false]) async {
    if (!_tracking) return;
    Future.delayed(AppConfig.trackPointTickTime, () async {
      try {
        TrackPoint tp = await TrackPoint.create();
        if (first) eventBusTrackingStatusChanged.fire(createEvent(tp: tp));
        _checkStatus(tp);

        eventBusTrackPointCreated.fire(createEvent(tp: tp));
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
