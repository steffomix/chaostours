import 'logger.dart';
import 'trackpoint.dart' show TrackPoint;
import 'trackingEvent.dart' show TrackingStatusChangedEvent;

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

  static void stop(tp) {
    if (_status != statusStop) {
      _status = statusStop;
      triggerStatusChangedEvent(
          TrackingStatusChangedEvent(tp, calculateDuration(tp)));
    }
  }

  static void move(tp) {
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
