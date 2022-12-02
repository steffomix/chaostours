import 'package:chaostours/trackingStatus.dart';

import 'trackPoint.dart';

class TrackingStatusChangedEvent {
  static final List<Function(TrackingStatusChangedEvent)> _listener = [];
  static TrackPoint _lastTrackPoint = TrackPoint();

  final TrackPoint trackPoint;
  final Duration duration;
  final int status;

  TrackingStatusChangedEvent(this.trackPoint, this.duration, this.status);

  static Duration calculateDuration(TrackPoint tp) {
    return _lastTrackPoint.time.difference(tp.time);
  }

  /// set status changed callback
  static void addListener(Function(TrackingStatusChangedEvent) fc) {
    for (var l in _listener) {
      if (l == fc) return;
    }
    _listener.add(fc);
  }

  static void trigger(TrackPoint tp) {
    var e = TrackingStatusChangedEvent(
        tp, calculateDuration(tp), TrackingStatus.status);
    _lastTrackPoint = tp;
    for (var cb in _listener) {
      cb(e);
    }
  }
}
