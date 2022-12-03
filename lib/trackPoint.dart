import 'package:flutter/material.dart';

import 'logger.dart';
import 'dart:math' show pow, sqrt;
import 'gps.dart';
import 'trackingEvent.dart';

class TrackPoint {
  static int _idStart = 0;
  static final List<TrackPoint> _trackPoints = [];
  static TrackPoint _stoppedAtTrackPoint = TrackPoint();
  static TrackPoint _startedAtTrackPoint = _stoppedAtTrackPoint;
  static const int statusStop = 0;
  static const int statusStart = 1;
  static int _status = 0;
  // time in minutes between two gps point to measure
  static const Duration timeTreshold = Duration(seconds: 5); // in minutes
  // distance in gps degree between two gps points (0.00145deg =  ~100m)
  static const double distanceTreshold = 0.002;
  static final Duration _maxStatusChangeSpeed =
      Duration(seconds: 20); // in minutes
  static DateTime _lastStatusChange =
      DateTime.now(); //.subtract(_maxStatusChangeSpeed);

  static int get status => _status;
  static DateTime get lastStatusChange => _lastStatusChange;
  static TrackPoint get startedAtTrackPoint => _startedAtTrackPoint;
  static TrackPoint get stoppedAtTrackPoint => _stoppedAtTrackPoint;

  static void start(TrackPoint tp) {
    if (_status != statusStart) {
      _status = statusStart;
      _triggerEvent(tp);
      _statusChanged();
    }
  }

  static void stop(TrackPoint tp) {
    if (_status != statusStop) {
      _status = statusStop;
      _triggerEvent(tp);
      _statusChanged();
    }
  }

  static void _statusChanged() {
    _lastStatusChange = DateTime.now();
  }

  static void _triggerEvent(TrackPoint tp) {
    try {
      TrackingStatusChangedEvent.triggerEvent(tp);
    } catch (e) {
      severe('TrackingStatusChangedEvent.trigger: ${e.toString()}');
    }
  }

  int _id = ++_idStart;
  final GPS _gps = GPS();
  final DateTime _time = DateTime.now();

  int get id => _id;
  bool get gpsOk => _gps.gpsOk;

  GPS get gps => _gps;

  DateTime get time => _time;

  TrackPoint() {
    Future.delayed(const Duration(milliseconds: 1), _nextTrackPoint);
  }

  void _nextTrackPoint() {
    log('------- TrackPoint ID: $id | Stop ID: ${_stoppedAtTrackPoint.id} | Start ID: ${_startedAtTrackPoint.id} -------');
    _trackPoints.add(this);
    _checkStatus();
  }

  void _checkStatus() {
    bool wait =
        _lastStatusChange.add(_maxStatusChangeSpeed).isAfter(DateTime.now());
    log('wait $wait');
    if (wait) return;
    if (_trackPoints.length < 10) return;
    while (_trackPoints.length > 100) {
      _trackPoints.removeAt(0);
    }

    // detect movement
    // find most recent track with gpsOk
    TrackPoint t = _trackPoints.last;
    int indexGpsOk = -1;
    for (var i = _trackPoints.length - 1; i >= 0; i--) {
      if (_trackPoints[i].gpsOk == true) {
        indexGpsOk = i;
        t = _trackPoints[i];
        break;
      }
    }

    // skip if t1 didn't change because no gpsOk was found
    if (indexGpsOk == -1) return;

    // go at least <timeTreshold> back
    // and look for next gps with gpsOk
    int timeDiff = 0;
    int indexTimeDiff = indexGpsOk;
    for (var i = indexGpsOk; i >= 0; i--) {
      timeDiff = t.time.difference(_trackPoints[i].time).inSeconds;
      if (_trackPoints[i].gpsOk == true && timeDiff >= timeTreshold.inSeconds) {
        indexTimeDiff = i;
        break;
      }
    }

    // now find movements between indexGpsOk and indexTimeDiff
    int indexMoved = indexGpsOk;
    for (var i = indexGpsOk; i >= indexTimeDiff; i--) {
      if (_trackPoints[i].gpsOk == true &&
          distance(_trackPoints[indexGpsOk], _trackPoints[i]) >
              distanceTreshold) {
        // movement detected
        t = _trackPoints[indexMoved];
        if (status == statusStop) {
          _startedAtTrackPoint = t;
          start(t);
        }
        return;
      }
      indexMoved = i;
    }
// now find if we are stopping for at least <timeTreshold>
    bool stopping = true;
    for (var i = indexGpsOk; i >= indexTimeDiff; i--) {
      if (_trackPoints[i].gpsOk == true &&
          distance(_trackPoints[indexGpsOk], _trackPoints[i]) >
              distanceTreshold) {
        stopping = false;
        break;
      }
    }
    if (stopping == true && _status == statusStart) {
      _stoppedAtTrackPoint = _trackPoints[indexGpsOk];
      stop(_stoppedAtTrackPoint);
    }
  }

  /// calculate distance between two gps points in plain degree
  double distance(TrackPoint t1, TrackPoint t2) {
    double dist = sqrt(
        pow(t1._gps.lat - t2._gps.lat, 2) + pow(t1._gps.lon - t2._gps.lon, 2));
    log('distance $dist');
    return dist;
  }
}
