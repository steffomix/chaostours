import 'trackPoint.dart' show TrackPoint;

class TrackingStatusChangedEvent {
  final TrackPoint trackPoint;
  final Duration duration;

  TrackingStatusChangedEvent(this.trackPoint, this.duration);
}
