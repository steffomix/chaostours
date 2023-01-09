import 'package:chaostours/globals.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/model_trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/event_manager.dart';

class TrackPoint {
  static TrackPoint? _instance;
  TrackPoint._() {
    /*
    EventManager(Events.onGps).addListener((dynamic gps) {
      trackBackground(gps as GPS);
    });
    */
    eventOnGps.on<GPS>().listen((GPS gps) async {
      await trackBackground(gps);
    });
  }
  factory TrackPoint() => _instance ??= TrackPoint._();

  //static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<ModelTrackPoint> _trackPoints = [];
  // contains all trackpoints during driving (from start to stop)
  static int get length => _trackPoints.length;
  //
  static TrackingStatus _status = TrackingStatus.none;
  static TrackingStatus get status => _status;
  static DateTime _lastStatusChange = DateTime.now();

  // if tracker is running
  static bool _tracking = false;
  static bool get tracking => _tracking;

  static String timeElapsed() {
    if (_trackPoints.isEmpty) return '00:00:00';
    return util.timeElapsed(
        _trackPoints.first.timeStart, _trackPoints.last.timeStart);
  }

  static double distance() {
    if (_trackPoints.isEmpty) return 0.0;
    double dist;
    if (_status == TrackingStatus.standing) {
      dist = GPS.distance(_trackPoints.first.gps, _trackPoints.last.gps);
    } else {
      dist = movedDistance(_trackPoints);
    }
    return (dist * 1000).round() / 1000;
  }

  static Future<void> _statusChanged(ModelTrackPoint tp) async {
    // create a new TrackPoint as event
    ModelTrackPoint event = await createEvent();
    if (Globals.osmLookup == OsmLookup.onStatus) {
      await tp.address.lookupAddress();
    }
    //if (_status == TrackingStatus.standing) {
    await ModelTrackPoint.insert(event);
    //}
    eventBusTrackingStatusChanged.fire(event);
    _trackPoints.clear();
    _trackPoints.add(tp);
    _lastStatusChange = DateTime.now();
  }

  static Future<ModelTrackPoint> createEvent() async {
    ModelTrackPoint event = await create();
    event.status = _status;
    event.timeStart = _trackPoints.first.timeStart;
    event.timeEnd = DateTime.now();
    event.trackPoints = [..._trackPoints];
    return event;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static void _checkStatus(ModelTrackPoint tp) {
    if (_trackPoints.length > 2) _statusChanged(tp);
    // wait after status changed
    if (_lastStatusChange
        .add(Globals.waitTimeAfterStatusChanged)
        .isAfter(DateTime.now())) {
      return;
    }
    // min length
    if (_trackPoints.length < 4) return;

    List<ModelTrackPoint> trackList = _recentTracks();
    // skip if nothing was found
    if (trackList.isEmpty) return;

    if (_status == TrackingStatus.standing || _status == TrackingStatus.none) {
      if (_checkMoved(trackList)) {
        // use the most recent Trackpoint as reference
        _statusChanged(trackList.first);
        _status = TrackingStatus.moving;
        return;
      }
    } else {
      if (_checkStopped(trackList)) {
        // use the one before oldest trackpoint where we stopped as reference
        _statusChanged(trackList.last);
        _status = TrackingStatus.standing;
        return;
      }
    }
  }

  static bool _checkMoved(List<ModelTrackPoint> tl) {
    // check if moved
    double dist = 0;
    ModelTrackPoint tRef = tl.last;
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i].gps, tRef.gps);
      if (dist > Globals.distanceTreshold) {
        return true;
      }
    }
    return false;
  }

  static bool _checkStopped(List<ModelTrackPoint> tl) {
    double dist = 0;
    double distMoved = 0;
    ModelTrackPoint tRef = tl.first;
    // check if stopped
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i].gps, tRef.gps);
      if (dist > distMoved) distMoved = dist;
    }
    logVerbose('moved: $distMoved in ${tl.length} tracks');
    if (distMoved < Globals.distanceTreshold) {
      return true;
    }
    return false;
  }

  /// collect recent Trackpoints in backwards order since last status changed
  /// and until <timeTreshold>
  /// so that trackList[0] is most recent
  static List<ModelTrackPoint> _recentTracks() {
    List<ModelTrackPoint> trackList = [];
    DateTime treshold = DateTime.now().subtract(Globals.stopTimeTreshold);
    bool outDated;
    for (var i = _trackPoints.length - 1; i >= 0; i--) {
      outDated = _trackPoints[i].timeStart.isBefore(treshold);
      if (outDated) break;
      trackList.add(_trackPoints[i]);
    }
    return trackList;
  }

  // calc distance over multiple trackpoints in meters
  static double movedDistance(List<ModelTrackPoint> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS gps = tracklist[0].gps;
    for (var i = 1; i < tracklist.length; i++) {
      dist += GPS.distance(gps, tracklist[i].gps);
      gps = tracklist[i].gps;
    }
    return dist;
  }

  static Future<ModelTrackPoint> create({GPS? backgroundGps}) async {
    GPS gps = backgroundGps ??= await GPS.gps();
    Address address = Address(gps);
    if (Globals.osmLookup == OsmLookup.always) await address.lookupAddress();

    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: <ModelTrackPoint>[],
        idAlias: ModelAlias.nextAlias(gps).map((e) => e.id).toList(),
        timeStart: DateTime.now(),
        address: address);

    return tp;
  }

  static bool _first = true;
  static Future<void> trackBackground(GPS gps) async {
    ModelTrackPoint tp;
    try {
      tp = await create();
      tp.status = _status;
      _trackPoints.add(tp);
      if (_first) {
        tp = await createEvent();
        tp.timeEnd = DateTime.now();
        _status = TrackingStatus.standing;
        eventBusTrackingStatusChanged.fire(await createEvent());
        _first = false;
      } else {
        _checkStatus(tp);
        eventBusTrackPointCreated.fire(tp);
      }
    } catch (e, stk) {
      // ignore
      logFatal('TrackPoint::create', e, stk);
    }
  }

  /// tracking heartbeat with <trackingTickTime> speed
  static Future<void> _track() async {
    if (!_tracking) return;
    Future.delayed(Globals.trackPointTickTime, () async {
      ModelTrackPoint tp;
      try {
        tp = await create();
        tp.status = _status;
        _trackPoints.add(tp);
        if (_first) {
          tp = await createEvent();
          tp.timeEnd = DateTime.now();
          _status = TrackingStatus.standing;
          eventBusTrackingStatusChanged.fire(await createEvent());
          _first = false;
        } else {
          _checkStatus(tp);
          eventBusTrackPointCreated.fire(tp);
        }
      } catch (e, stk) {
        // ignore
        logFatal('TrackPoint::create', e, stk);
      }
      _track();
    });
  }

  /// start tracking heartbeat
  static Future<void> startTracking() async {
    if (_tracking) return;
    await TrackPoint.create();
    logInfo('start tracking');
    _tracking = true;
    _track();
  }

  /// stop tracking heartbeat
  static void stopTracking() {
    if (!_tracking) return;
    logInfo('stop tracking');
    _tracking = false;
  }
}
