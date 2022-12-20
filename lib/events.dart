import 'track_point.dart';
import 'package:event_bus/event_bus.dart';

class EventBase {
  final DateTime time = DateTime.now();
}

// fired when status changed
EventBus trackingStatusEvents = EventBus();

class TrackingStatusChangedEvent extends EventBase {
  final List<TrackPoint> trackPoints;
  final TrackingStatus status;

  TrackingStatusChangedEvent(this.trackPoints, this.status);
}

// fired when new trackpoint is created
EventBus trackPointEvent = EventBus();

class TrackPointEvent extends EventBase {
  final List<TrackPoint> trackPoints;

  TrackPointEvent(this.trackPoints);
}

EventBus onTapEvent = EventBus();

class Tapped {}
