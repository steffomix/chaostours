import 'config.dart';
import 'log.dart';
import 'util.dart';
import 'gps.dart';
import 'events.dart';
import 'location_alias.dart';
import 'address.dart';

enum TrackingStatus {
  stop,
  start;
}

class TrackPoint {
  static Future<TrackPoint> create() async {
    GPS gps = await GPS.gps();
    num dist = _trackPoints.isNotEmpty
        ? GPS.distance(_trackPoints.last._gps, gps).round()
        : 0;

    TrackPoint tp = TrackPoint(gps);
    await tp.address.lookupAddress();
    logInfo(
        'TrackPoint::create TrackPoint #${tp.id} with GPS #${gps.id} at dist $dist meters\n'
        'at address ${tp.address.asString}');
    return tp;
  }

  static int _nextId = 0;
  // contains all trackpoints from current state start or stop
  static final List<TrackPoint> _trackPoints = [];
  // contains all trackpoints during driving (from start to stop)
  static final List<TrackPoint> driverTrackPoints = [];
  // both will be created in TrackPoint.startTracking();
  static late TrackPoint _stoppedAtTrackPoint;
  static late TrackPoint _startedAtTrackPoint;

  static double _idleDistanceMoved = 0;
  static double _distanceMoved = 0;

  //
  static TrackingStatus _status = TrackingStatus.stop;
  static TrackingStatus get status => _status;
  static DateTime _lastStatusChange = DateTime.now();
  static DateTime get lastStatusChange => _lastStatusChange;
  static TrackPoint get startedAtTrackPoint => _startedAtTrackPoint;
  static TrackPoint get stoppedAtTrackPoint => _stoppedAtTrackPoint;

  // if tracker is running
  static bool _tracking = false;
  static bool get tracking => _tracking;

  // distance needed to trigger start in gps degree (0.00145deg = ~100meters)
  static double get distanceTreshold => AppConfig.distanceTreshold;
  // distance moved around during stop
  static double get distanceMoved => _distanceMoved;
  // distance moved during start
  static double get idleDistanceMoved => _idleDistanceMoved;

// change status to start
  static void start(TrackPoint tp) async {
    if (_status == TrackingStatus.start) return;
    String s = timeElapsed(tp.time, _stoppedAtTrackPoint.time);
    logInfo('### start ### after $s');
    _status = TrackingStatus.start;
    _startedAtTrackPoint = tp;

    try {
      tp._alias = await LocationAlias.findAlias(tp._gps.lat, tp._gps.lon);
    } catch (e, stk) {
      // ignore
      logError('find alias', e, stk);
    }
    _statusChanged(tp);
    _trackPoints.clear();
    _trackPoints.add(_stoppedAtTrackPoint);
  }

// change status to stop
  static void stop(TrackPoint tp) async {
    if (_status == TrackingStatus.stop) return;
    String s = timeElapsed(tp.time, _startedAtTrackPoint.time);
    logInfo('### stop ### moved ${_distanceMoved.round()} meters in $s');
    _status = TrackingStatus.stop;
    _stoppedAtTrackPoint = tp;
    TrackPoint._distanceMoved =
        GPS.distance(_stoppedAtTrackPoint._gps, _startedAtTrackPoint._gps);
    driverTrackPoints.addAll(_trackPoints);
    //
    try {
      tp._alias = await LocationAlias.findAlias(tp._gps.lat, tp._gps.lon);
    } catch (e, stk) {
      // ignore
      logError('find alias', e, stk);
    }
    _statusChanged(tp);
    _trackPoints.clear();
    _trackPoints.add(tp);
  }

// trigger status change event
  static void _statusChanged(TrackPoint tp) {
    trackingStatusEvents.fire(TrackingStatusChangedEvent(tp, status));
    _lastStatusChange = DateTime.now();
    _distanceMoved = 0;
    _idleDistanceMoved = 0;
  }

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
    address = Address(_gps);
    _trackPoints.add(this);
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

    if (_status == TrackingStatus.stop) {
      if (_checkMoved(trackList)) {
        // use the most recent Trackpoint as reference
        start(trackList.first);
        return;
      }
    } else {
      if (_checkStopped(trackList)) {
        // use the oldest trackpoint where we stopped as reference
        stop(trackList.last);
        return;
      }
    }
  }

  static bool _checkMoved(List<TrackPoint> tl) {
    // check if moved
    double dist = 0;
    TrackPoint tRef = _stoppedAtTrackPoint;
    for (var i = 0; i < tl.length; i++) {
      dist = GPS.distance(tl[i]._gps, tRef._gps);
      if (dist > _idleDistanceMoved) _idleDistanceMoved = dist;
      if (dist > distanceTreshold) {
        return true;
      }
    }
    logVerbose('idle Distance $_idleDistanceMoved');
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
      _distanceMoved = movedDistance();
      return true;
    }
    return false;
  }

  static double movedDistance() {
    List<GPS> tracks = [];
    for (var i in _trackPoints) {
      tracks.add(i.gps);
    }
    if (tracks.length < 2) return 0;
    double dist = 0;
    GPS gps = tracks.first;
    for (var i = 1; i < tracks.length; i++) {
      dist += GPS.distance(gps, tracks[i]);
      gps = tracks[i];
    }
    return dist;
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
    _startedAtTrackPoint = _stoppedAtTrackPoint = await TrackPoint.create();
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
