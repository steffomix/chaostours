import 'logger.dart';
import 'trackpoint.dart' show TrackPoint;
import 'trackingEvent.dart';

class TrackingStatus {
  static const int statusStop = 0;
  static const int statusMove = 1;
  static int _status = 0;

  static int get status {
    return _status;
  }

  static void stop(TrackPoint tp) {
    if (_status != statusStop) {
      _status = statusStop;
      _triggerEvent(tp);
    }
  }

  static void _triggerEvent(TrackPoint tp) {
    try {
      TrackingStatusChangedEvent.trigger(tp);
    } catch (e) {
      severe('TrackingStatusChangedEvent.trigger: ${e.toString()}');
    }
  }

  static void move(TrackPoint tp) {
    if (_status != statusMove) {
      _status = statusMove;
      _triggerEvent(tp);
    }
  }
}
