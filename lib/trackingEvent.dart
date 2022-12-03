import 'logger.dart';
import 'address.dart';
import 'trackPoint.dart';

class TrackingStatusChangedEvent {
  static final List<Function(TrackingStatusChangedEvent)> _listener = [];
  static TrackPoint _lastTrackPoint = TrackPoint();

  final TrackPoint trackPoint;
  final Address address;
  final Duration duration;
  final int status;

  TrackingStatusChangedEvent(
      this.trackPoint, this.address, this.duration, this.status);

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

  static void triggerEvent(tp) {
    Address(tp.gps).lookupAddress().then((Address address) {
      var event = TrackingStatusChangedEvent(
          tp, address, calculateDuration(tp), TrackPoint.status);
      _lastTrackPoint = tp;
      log('trigger event to status ${TrackPoint.status == 0 ? 'stop' : 'move'}');
      for (var cb in _listener) {
        try {
          cb(event);
        } catch (e) {
          severe('Trigger TrackingStatusChangedEvent failed: ${e.toString()}');
        }
      }
    }).onError((error, stackTrace) {
      severe('Lookup Address failed: ${error.toString()}');
    });
  }
}
