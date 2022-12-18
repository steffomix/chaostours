import 'log.dart';
import 'track_point.dart';

class TrackingStatusChangedEvent {
  static final List<Function(TrackPoint)> _listeners = [];

  /// set status changed callback
  static void addListener(Function(TrackPoint) fn) {
    for (var l in _listeners) {
      if (l == fn) return;
    }
    logInfo('TrackingStatusChangedEvent::addListener ${fn.toString()}');
    _listeners.add(fn);
  }

  static void triggerEvent(TrackPoint tp) async {
    // dispatch event
    for (var fn in _listeners) {
      try {
        fn(tp);
      } catch (e, stk) {
        logFatal('Trigger TrackingStatusChangedEvent failed', e, stk);
      }
    }
  }
}
