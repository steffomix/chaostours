import 'package:event_bus/event_bus.dart';

EventBus eventOnGps = EventBus(sync: true);

// set the main screen id
EventBus eventBusMainPaneChanged = EventBus();

// BottomNavBar enets
EventBus eventBusTapBottomNavBarIcon = EventBus();

// TrackPoint List Item on main screen
//EventBus eventBusTrackPointEventSelected = EventBus();

// fired when trackPoint status changed
EventBus eventBusTrackingStatusChanged = EventBus();

// fired when new trackpoint is created
EventBus eventBusTrackPointCreated = EventBus();

class EventBase {
  final DateTime time = DateTime.now();
}

class Tapped extends EventBase {
  final int id;
  Tapped(this.id);
}
/*
class TrackPointEvent extends ModelTrackPoint {
  static int _eventId = 0;
  int eventId = -1;
  final TrackingStatus status;
  final List<TrackPoint> trackList;
  final Address address;
  ModelTrackPoint? model;

  TrackPointEvent(
      {required this.status,
      required lat,
      required lon,
      required timeStart,
      required timeEnd,
      required this.address,
      required this.trackList,
      required idAlias,
      this.model})
      : super(
            lat: lat,
            lon: lon,
            timeStart: timeStart,
            timeEnd: timeEnd,
            idAlias: <int>{},
            idTask: <int>{},
            trackPoints: <GPS>{});

  //double get lat => model == null ? lat : model!.lat;
  //double get lon => model == null ? lon : model!.lon;
  //DatTime get timeStart => model == null ? timeStart : model!.timeStart;

  double? _distancePath;
  double get distancePath {
    return _distancePath ??= TrackPoint.movedDistance(trackList);
  }

  double? _distanceStraight;
  double get distanceStraight {
    if (trackList.isEmpty) return 0.0;
    return _distanceStraight ??=
        GPS.distance(trackList.first.gps, trackList.last.gps);
  }

  Duration? _duration;
  Duration get duration {
    if (trackList.isEmpty) return const Duration();
    return _duration ??=
        util.duration(trackList.first.time, trackList.last.time);
  }

  static List<TrackPointEvent> recentEvents({int max = 30}) {
    List<ModelTrackPoint> models = ModelTrackPoint.recentTrackPoints(max: max);
    List<TrackPointEvent> trackPoints = [];
    for (var m in models) {
      trackPoints.add(TrackPointEvent(
          status: TrackingStatus.standing, // event only
          trackList: [], // event only
          address: Address(GPS(m.lat, m.lon)), // event only
          model: m, // event only
          lat: m.lat,
          lon: m.lon,
          timeStart: m.timeStart,
          timeEnd: m.timeEnd,
          idAlias: m.idAlias));
    }
    return trackPoints;
  }

  TrackPointEvent statusChanged() {
    // ignore: unused_local_variable
    var calculatePath = _distancePath = _distanceStraight;
    // ignore: unused_local_variable
    var calculateDur = duration;
    var last = trackList.last;
    trackList.clear();
    trackList.add(last);
    return this;
  }
}
*/