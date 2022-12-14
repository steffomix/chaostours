import 'config.dart';
import 'logger.dart';
import 'util.dart';
import 'gps.dart';
import 'trackingEvent.dart';
import 'locationAlias.dart';

class TrackPoint {
  static Future<TrackPoint> create() async {
    GPS gps = await GPS.gps();
    return TrackPoint(gps);
  }

  static int _nextId = 0;
  static final List<TrackPoint> _trackPoints = [];
  // both will be created in TrackPoint.startTracking();
  static late TrackPoint _stoppedAtTrackPoint;
  static late TrackPoint _startedAtTrackPoint;
  static double _idleDistance = 0;
  static double _movedDistance = 0;

  //
  static const int statusStop = 0;
  static const int statusStart = 1;
  static int _status = 0;
  static int get status => _status;
  static DateTime _lastStatusChange = DateTime.now();
  static DateTime get lastStatusChange => _lastStatusChange;
  static TrackPoint get startedAtTrackPoint => _startedAtTrackPoint;
  static TrackPoint get stoppedAtTrackPoint => _stoppedAtTrackPoint;

  // if tracker is running
  static bool _tracking = false;
  static bool get tracking => _tracking;

  // durations and distances
  // skip status check for given time to prevent ugly things
  static Duration get waitTimeAfterStatusChanged {
    return AppConfig.debugMode
        ? const Duration(seconds: 3)
        : const Duration(minutes: 3);
  }

  // stop time needed to trigger stop
  static Duration get timeTreshold {
    return AppConfig.debugMode
        ? const Duration(seconds: 10)
        : const Duration(minutes: 5);
  }

  // check status interval
  static Duration get tickTime {
    return AppConfig.debugMode
        ? const Duration(seconds: 2)
        : const Duration(seconds: 20);
  }

  // distance needed to trigger start in gps degree (0.00145deg = ~100meters)
  static double get distanceTreshold => AppConfig.distanceTreshold;
  // distance moved around during stop
  static double get distanceMoved => _movedDistance;
  // distance moved during start
  static double get awayFromStop => _idleDistance;

// change status to start
  static void start(TrackPoint tp) {
    if (_status == statusStart) return;
    String s = timeElapsed(tp.time, _stoppedAtTrackPoint.time);
    log('### start ### after $s');
    _status = statusStart;
    _startedAtTrackPoint = tp;
    _statusChanged(tp);
    _trackPoints.clear();
    _trackPoints.add(_stoppedAtTrackPoint);
  }

// change status to stop
  static void stop(TrackPoint tp) {
    if (_status == statusStop) return;
    String s = timeElapsed(tp.time, _startedAtTrackPoint.time);
    log('### stop ### moved ${_movedDistance.round()} meters in $s');
    _status = statusStop;
    _stoppedAtTrackPoint = tp;
    LocationAlias.alias(tp._gps.lat, tp._gps.lon, tp.alias);
    _statusChanged(tp);
    _trackPoints.clear();
    _trackPoints.add(tp);
  }

// trigger status change event
  static void _statusChanged(TrackPoint tp) {
    TrackingStatusChangedEvent.triggerEvent(tp);
    _lastStatusChange = DateTime.now();
    _movedDistance = 0;
    _idleDistance = 0;
  }

  final int _id = ++_nextId;
  final GPS _gps;
  final DateTime _time = DateTime.now();
  final int _localStatus = TrackPoint._status;
  final List<Alias> alias = [];

  int get id => _id;
  GPS get gps => _gps;
  DateTime get time => _time;
  int get localstatus => _localStatus;

  TrackPoint(this._gps) {
    _trackPoints.add(this);
  }

  /// collect recent Trackpoints in backwards order since last status changed with gpsOk
  /// so that trackList[0] is most recent
  static List<TrackPoint> _recentTracks() {
    // collect TrackPoints of last <timeTreshold> with <gpsOk>
    List<TrackPoint> trackList = [];
    List<int> ids = [];
    DateTime treshold = DateTime.now().subtract(timeTreshold);
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
        .add(waitTimeAfterStatusChanged)
        .isAfter(DateTime.now())) {
      return;
    }
    // min length
    if (_trackPoints.length < 5) return;

    List<TrackPoint> trackList = _recentTracks();
    // skip if nothing was found
    if (trackList.isEmpty) return;

    if (_status == statusStop) {
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
      if (dist > _idleDistance) _idleDistance = dist;
      if (dist > distanceTreshold) {
        return true;
      }
    }
    log('idleDist $_idleDistance');
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
    log('moved: $distMoved in ${tl.length} tracks');
    if (distMoved < distanceTreshold) {
      _movedDistance = movedDistance();
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
    Future.delayed(tickTime, () async {
      TrackPoint tp = await TrackPoint.create();
      _checkStatus(tp);
      _track();
    });
  }

  /// start tracking heartbeat
  static void startTracking() async {
    if (_tracking) return;
    _startedAtTrackPoint = _stoppedAtTrackPoint = await TrackPoint.create();
    log('start tracking');
    _tracking = true;
    _track();
  }

  /// stop tracking heartbeat
  static void stopTracking() {
    if (!_tracking) return;
    log('stop tracking');
    _tracking = false;
  }
}
