import 'track_point.dart';
import 'package:event_bus/event_bus.dart';

class TrackingStatusChangedEvent {
  final TrackPoint trackPoint;
  final TrackingStatus status;

  TrackingStatusChangedEvent(this.trackPoint, this.status);
}

EventBus trackingStatusEvents = EventBus();
