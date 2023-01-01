import 'package:chaostours/track_point.dart';
import 'package:event_bus/event_bus.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/enum.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/address.dart';

// set the main screen id
EventBus eventBusMainPaneChanged = EventBus();

// BottomNavBar enets
EventBus eventBusTapBottomNavBarIcon = EventBus();

// TrackPoint List Item on main screen
EventBus eventBusTrackPointEventSelected = EventBus();

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

class TrackPointEvent extends ModelTrackPoint {
  static int _eventId = 0;
  int eventId = -1;
  final TrackingStatus status;
  final List<TrackPoint> trackList;
  final Address address;
  ModelTrackPoint? model;
  List<ModelAlias> aliasList;

  TrackPointEvent(
      {required lat,
      required lon,
      required timeStart,
      required timeEnd,
      required this.status,
      required this.address,
      required this.trackList,
      required this.aliasList,
      this.model})
      : super(
            lat: lat,
            lon: lon,
            timeStart: timeStart,
            timeEnd: timeEnd,
            idAlias: <int>{},
            idTask: <int>{},
            trackPoints: <GPS>{}) {
    eventId = ++_eventId;
    for (var e in aliasList) {
      idAlias.add(e.id);
    }
  }

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
          lat: m.lat,
          lon: m.lon,
          timeStart: m.timeStart,
          timeEnd: m.timeEnd,
          status: TrackingStatus.standing,
          address: Address(GPS(m.lat, m.lon)),
          trackList: [],
          aliasList: m.getAlias()));
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
