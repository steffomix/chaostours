import 'package:flutter/material.dart';

import 'logger.dart';
import 'dart:math' show pow, sqrt;
import 'gps.dart';
import 'trackingStatus.dart';

class TrackPoint {
  static final List<TrackPoint> _trackPoints = [];
  final GPS _gps = GPS();
  final DateTime _time = DateTime.now();

  // time in minutes between two gps point to measure
  static const int timeTreshold = 15; // in minutes
  // distance in gps degree between two gps points (0.00145deg =  ~100m)
  static const double distanceTreshold = 0.00145 * 5;

  bool get gpsOk {
    return _gps.gpsOk;
  }

  GPS get gps {
    return gps;
  }

  DateTime get time {
    return _time;
  }

  TrackPoint() {
    Future.delayed(const Duration(milliseconds: 10), _addTrackPoint);
  }

  void _addTrackPoint() {
    _trackPoints.add(this);
    while (_trackPoints.length > 100) {
      _trackPoints.removeAt(0);
    }
    if (_trackPoints.length < 10) return;

    // find first track with gpsOk
    TrackPoint t1 = _trackPoints.last;
    TrackPoint t2 = t1;
    int index = _trackPoints.length - 2;
    for (var i = index; i > 0; i--) {
      if (_trackPoints[i].gpsOk == true) {
        t1 = _trackPoints[i];
        index = i - 1;
        break;
      }
    }

    // skip if no gpsOk was found
    if (t1 == t2) return;
    // go at least <timeDifference> back
    // and look for next gps with gpsOk
    int diff = 0;
    for (var i = index; i >= 0; i--) {
      diff = t1.time.difference(_trackPoints[i].time).inSeconds;
      if (_trackPoints[i].gpsOk == true && diff >= timeTreshold) {
        t2 = _trackPoints[i];
        index = i;
        break;
      }
    }

    try {
      if (distance(t1, t2) > distanceTreshold) {
        TrackingStatus.move(t2);
      } else {
        TrackingStatus.stop(t2);
      }
    } catch (e) {
      severe('Change Tracking Status failed: ${e.toString()}');
    }
  }

  /// calculate distance between two gps points in plain degree
  double distance(TrackPoint t1, TrackPoint t2) {
    double dist = sqrt(
        pow(t1._gps.lat - t2._gps.lat, 2) + pow(t1._gps.lon - t2._gps.lon, 2));
    info('gps distance $dist');
    return dist;
  }
}


/*
class TrackingStatus {
  static TrackPoint _lastTrackPoint = TrackPoint();
  static final List<Function(TrackingStatusChangedEvent)> _listener = [];
  static const int statusStop = 0;
  static const int statusMove = 1;
  static int _status = 0;

  int get status {
    return _status;
  }

  /// set status changed callback
  static void addListener(Function(TrackingStatusChangedEvent) t) {
    for (Function(TrackingStatusChangedEvent) l in _listener) {
      if (l == t) return;
    }
    _listener.add(t);
  }

  static void triggerStatusChangedEvent(t) {
    for (Function(TrackingStatusChangedEvent) cb in _listener) {
      cb(t);
    }
  }

  static void stop(TrackPoint tp) {
    if (_status != statusStop) {
      _status = statusStop;
      triggerStatusChangedEvent(
          TrackingStatusChangedEvent(tp, calculateDuration(tp)));
    }
  }

  static void move(TrackPoint tp) {
    if (_status != statusMove) {
      _status = statusMove;
      TrackingStatusChangedEvent e =
          TrackingStatusChangedEvent(tp, calculateDuration(tp));
      triggerStatusChangedEvent(e);
    }
  }

  static Duration calculateDuration(TrackPoint tp) {
    return _lastTrackPoint.time.difference(tp.time);
  }
}
*/