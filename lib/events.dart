import 'package:chaostours/track_point.dart';
import 'package:event_bus/event_bus.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/util.dart' as util;

EventBus onTapEvent = EventBus(sync: true);

class Tapped {
  final int id;
  Tapped(this.id);
}

// fired when trackPoint status changed
EventBus trackingStatusChangedEvents = EventBus(sync: false);

// fired when new trackpoint is created
EventBus trackPointCreatedEvents = EventBus(sync: false);

class EventBase {
  final DateTime time = DateTime.now();
}

class TrackPointEvent extends EventBase {
  final TrackingStatus status;
  final TrackPoint caused;
  final TrackPoint stopped;
  final TrackPoint started;
  final List<TrackPoint> trackList;
  double? _distancePath;
  double get distancePath {
    return _distancePath ??= TrackPoint.movedDistance(trackList);
  }

  double? _distanceStraight;
  double get distanceStraight {
    return _distanceStraight ??=
        GPS.distance(trackList.first.gps, trackList.last.gps);
  }

  Duration? _duration;
  Duration get duration {
    return _duration ??=
        util.duration(trackList.first.time, trackList.last.time);
  }

  TrackPointEvent statusChanged() {
    var calculatePath = _distancePath = _distanceStraight;
    var calculateDur = duration;
    var last = trackList.last;
    trackList.clear();
    trackList.add(last);
    return this;
  }

  TrackPointEvent(
      {required this.status,
      required this.caused,
      required this.stopped,
      required this.started,
      required this.trackList}) {}
}
