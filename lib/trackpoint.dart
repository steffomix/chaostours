import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/events.dart';

class TrackPoint {
  static final Logger logger = Logger.logger<TrackPoint>();
  factory TrackPoint() => _instance ??= TrackPoint._();
  static TrackPoint? _instance;
  TrackPoint._() {
    EventManager.listen<EventOnBackgroundGpsChanged>(trackPoint);
  }

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
  //static bool _tracking = false;
  //static bool get tracking => _tracking;

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
    logger.important('Tracking Status changed to $status');
    ModelTrackPoint event = await createEvent();
    if (Globals.osmLookup == OsmLookup.onStatus) {
      logger.log('lookup address');
      await tp.address.lookupAddress();
    }
    await ModelTrackPoint.insert(event);

    EventManager.fire<EventOnTrackingStatusChanged>(
        EventOnTrackingStatusChanged(tp));
    _trackPoints.clear();
    _trackPoints.add(tp);
    _lastStatusChange = DateTime.now();
  }

  static Future<ModelTrackPoint> createEvent() async {
    logger.verbose('create trackpoint event');
    ModelTrackPoint event =
        await create(EventOnBackgroundGpsChanged(await GPS.gps()));
    event.status = _status;
    event.timeStart = _trackPoints.first.timeStart;
    event.timeEnd = DateTime.now();
    event.trackPoints = _trackPoints.map((e) => e.gps).toList();
    return event;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static void _checkStatus(ModelTrackPoint tp) {
    logger.verbose('check status');
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
    logger.verbose('moved: $distMoved in ${tl.length} tracks');
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

  static Future<ModelTrackPoint> create(
      EventOnBackgroundGpsChanged event) async {
    logger.verbose(
        'create trackpoint from gps ${event.gps.lat},${event.gps.lon}');
    GPS gps = event.gps;
    Address address = Address(gps);
    if (Globals.osmLookup == OsmLookup.always) await address.lookupAddress();

    ModelTrackPoint tp = ModelTrackPoint(
        gps: gps,
        trackPoints: <GPS>[],
        idAlias: ModelAlias.nextAlias(gps).map((e) => e.id).toList(),
        timeStart: DateTime.now(),
        address: address);
    logger.important('trigger EventOnTrackPoint');
    EventManager.fire<EventOnTrackPoint>(EventOnTrackPoint(tp));
    return tp;
  }

  static bool _first = true;
  static Future<void> trackPoint(EventOnBackgroundGpsChanged event) async {
    ModelTrackPoint tp;
    try {
      tp = await create(event);
      tp.status = _status;
      _trackPoints.add(tp);
      if (_first) {
        tp = await createEvent();
        tp.timeEnd = DateTime.now();
        _status = TrackingStatus.standing;
        EventManager.fire<EventOnTrackingStatusChanged>(
            EventOnTrackingStatusChanged(await createEvent()));
        _first = false;
      } else {
        _checkStatus(tp);
      }
    } catch (e, stk) {
      // ignore
      logger.fatal('trackPoint: $e', stk);
    }
  }
/*
  /// tracking heartbeat with <trackingTickTime> speed
  static Future<void> _track() async {
    if (!_tracking) return;
    Future.delayed(Globals.trackPointTickTime, () async {
      ModelTrackPoint tp;
      try {
        tp = await create(EventOnGps(await GPS.gps()));
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
        fatal('TrackPoint::create', e, stk);
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
  */
}
