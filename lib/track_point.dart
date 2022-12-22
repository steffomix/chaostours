import 'package:chaostours/config.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/location_alias.dart';
import 'package:chaostours/address.dart';

enum TrackingStatus {
  standing,
  moving;
}

class TrackPoint {
  static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<TrackPoint> _trackPoints = [];
  // contains all trackpoints during driving (from start to stop)
  static final List<TrackPoint> driverTrackPoints = [];
  // both will be created in TrackPoint.startTracking();
  static TrackPoint? _stoppedAtTrackPoint;
  static TrackPoint? _startedAtTrackPoint;

  //
  static TrackingStatus _status = TrackingStatus.standing;
  static TrackingStatus get status => _status;
  static DateTime _lastStatusChange = DateTime.now();

  // if tracker is running
  static bool _tracking = false;
  static bool get tracking => _tracking;

  // distance needed to trigger start in gps degree (0.00145deg = ~100meters)
  static double get distanceTreshold => AppConfig.distanceTreshold;

  final int _id = ++_nextId;
  final GPS _gps;
  final DateTime _time = DateTime.now();
  List<Alias> _alias = [];

  int get id => _id;
  GPS get gps => _gps;
  DateTime get time => _time;
  List<Alias> get alias => _alias;
  late Address address;

  TrackPoint(this._gps) {
    _trackPoints.add(this);
  }

  static TrackPointEvent createEvent(TrackPoint tp) {
    return TrackPointEvent(
        status: TrackPoint.status,
        caused: tp,
        stopped: _stoppedAtTrackPoint ??= tp,
        started: _startedAtTrackPoint ??= tp,
        trackList: <TrackPoint>[..._trackPoints]);
  }

  // change status to start
  static void start(TrackPoint tp) async {
    if (_status == TrackingStatus.moving) return;
    _status = TrackingStatus.moving;
    _startedAtTrackPoint = tp;
    trackingStatusChangedEvents.fire(createEvent(tp).statusChanged());
    _trackPoints.clear();
    _trackPoints.add(_stoppedAtTrackPoint ??= tp);
  }

// change status to stop
  static void stop(TrackPoint tp) async {
    if (_status == TrackingStatus.standing) return;
    _status = TrackingStatus.standing;
    _stoppedAtTrackPoint = tp;
    driverTrackPoints.addAll(_trackPoints);
    trackingStatusChangedEvents.fire(createEvent(tp).statusChanged());
    _trackPoints.clear();
    _trackPoints.add(tp);
  }

  /// collect recent Trackpoints in backwards order since last status changed with gpsOk
  /// so that trackList[0] is most recent
  static List<TrackPoint> _recentTracks() {
    // collect TrackPoints of last <timeTreshold> with <gpsOk>
    List<TrackPoint> trackList = [];
    List<int> ids = [];
    DateTime treshold = DateTime.now().subtract(AppConfig.stopTimeTreshold);
    bool outDated;
    for (var i = _trackPoints.length - 1; i >= 0; i--) {
      outDated = _trackPoints[i].time.isBefore(treshold);
      if (outDated) break;
      trackList.add(_trackPoints[i]);
      ids.add(_trackPoints[i].id);
    }
    return trackList;
  }

  ///
  /// creates new Trackpoint, waits after status changed,
  ///
  static void _checkStatus(TrackPoint tp) {
    // wait after status changed
    if (_lastStatusChange
        .add(AppConfig.waitTimeAfterStatusChanged)
        .isAfter(DateTime.now())) {
      return;
    }
    // min length
    if (_trackPoints.length < 4) return;

    List<TrackPoint> trackList = _recentTracks();
    // skip if nothing was found
    if (trackList.isEmpty) return;

    if (_status == TrackingStatus.standing) {
      if (_checkMoved(trackList)) {
        // use the most recent Trackpoint as reference
        start(trackList.first);
        return;
      }
    } else {
      if (_checkStopped(trackList)) {
        // use the one before oldest trackpoint where we stopped as reference
        stop(trackList.last);
        return;
      }
    }
  }

  static bool _checkMoved(List<TrackPoint> tl) {
    // check if moved
    double dist = 0;
    TrackPoint tRef = _stoppedAtTrackPoint ??= tl.last;
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i]._gps, tRef._gps);
      if (dist > distanceTreshold) {
        return true;
      }
    }
    return false;
  }

  static bool _checkStopped(List<TrackPoint> tl) {
    double dist = 0;
    double distMoved = 0;
    TrackPoint tRef = tl.first;
    // check if stopped
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i]._gps, tRef._gps);
      if (dist > distMoved) distMoved = dist;
    }
    logVerbose('moved: $distMoved in ${tl.length} tracks');
    if (distMoved < distanceTreshold) {
      return true;
    }
    return false;
  }

  // calc distance in meters
  static double movedDistance(List<TrackPoint> tracklist) {
    if (tracklist.length < 2) return 0;
    double dist = 0;
    GPS gps = tracklist[0]._gps;
    for (var i = 1; i < tracklist.length; i++) {
      dist += GPS.distance(gps, tracklist[i]._gps);
      gps = tracklist[i]._gps;
    }
    return dist;
  }

  static Future<TrackPoint> create() async {
    GPS gps = await GPS.gps();
    num dist = _trackPoints.isNotEmpty
        ? GPS.distance(_trackPoints.last._gps, gps).round()
        : 0;

    TrackPoint tp = TrackPoint(gps);

    tp.address = Address(gps);
    await tp.address.lookupAddress();
    tp._alias = await LocationAlias.findAlias(tp._gps.lat, tp._gps.lon);

    trackPointCreatedEvents.fire(createEvent(tp));
/*
    logInfo(
        'TrackPoint::create TrackPoint #${tp.id} with GPS #${gps.id} at dist $dist meters\n'
        'at address ${tp.address.asString}\n'
        'with alias ${tp.alias.isEmpty ? ' - ' : tp.alias[0].alias}');
*/
    return tp;
  }

  /// tracking heartbeat with <trackingTickTime> speed
  static void _track() async {
    if (!_tracking) return;
    Future.delayed(AppConfig.trackPointTickTime, () async {
      try {
        TrackPoint tp = await TrackPoint.create();
        _checkStatus(tp);
      } catch (e, stk) {
        // ignore
        logFatal('TrackPoint::create', e, stk);
      }
      _track();
    });
  }

  /// start tracking heartbeat
  static void startTracking() async {
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
