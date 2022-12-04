import 'config.dart';
import 'logger.dart';
import 'gps.dart';
import 'trackingEvent.dart';

class TrackPoint {
  static int _nextId = 0;
  static final List<TrackPoint> _trackPoints = [];
  static TrackPoint _stoppedAtTrackPoint = TrackPoint();
  static TrackPoint _startedAtTrackPoint = _stoppedAtTrackPoint;
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
    Duration d = tp.time.difference(_stoppedAtTrackPoint.time);
    String t = ' ${d.inHours > 0 ? '${d.inHours} Stunden, ' : ''}'
        '${d.inMinutes > 0 ? '${d.inMinutes} Minuten, ' : ''}'
        '${d.inSeconds > 0 ? '${d.inSeconds} Sekunden' : ''}';
    t = t.trim();
    log('### start ### after $t');
    _status = statusStart;
    _startedAtTrackPoint = tp;
    _statusChanged(tp);
  }

// change status to stop
  static void stop(TrackPoint tp) {
    if (_status == statusStop) return;
    log('### stop ### moved $_movedDistance meters');
    _status = statusStop;
    _stoppedAtTrackPoint = tp;
    _statusChanged(tp);
  }

// trigger status change event
  static void _statusChanged(TrackPoint tp) {
    TrackingStatusChangedEvent.triggerEvent(tp);
    _lastStatusChange = DateTime.now();
    _movedDistance = 0;
    _idleDistance = 0;
    _trackPoints.clear();
  }

  final int _id = ++_nextId;
  final GPS _gps = GPS();
  final DateTime _time = DateTime.now();

  int get id => _id;
  bool get gpsOk => _gps.gpsOk;
  GPS get gps => _gps;
  DateTime get time => _time;

  TrackPoint() {
    _trackPoints.add(this);
  }

  static List<TrackPoint> _recentTracks() {
    // collect TrackPoints of last <timeTreshold> with <gpsOk>
    List<TrackPoint> trackList = [];
    List<int> ids = [];
    DateTime treshold = DateTime.now().subtract(timeTreshold);
    bool outDated;
    for (var i = _trackPoints.length - 1; i >= 0; i--) {
      outDated = _trackPoints[i].time.isBefore(treshold);
      if (outDated) break;
      if (_trackPoints[i].gpsOk == true) {
        trackList.add(_trackPoints[i]);
        ids.add(_trackPoints[i].id);
      }
    }
    return trackList;
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
      log('idleDist $_idleDistance');
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
    log('moved: $distMoved in ${tl.length} tracks');
    if (distMoved < distanceTreshold) {
      return true;
    }
    _movedDistance = movedDistance();
    return false;
  }

  static void _checkStatus() {
    TrackPoint();
    // wait
    if (_lastStatusChange
        .add(waitTimeAfterStatusChanged)
        .isAfter(DateTime.now())) {
      return;
    }
    // check distance reference is valid
    if (_stoppedAtTrackPoint.gpsOk == false) {
      _stoppedAtTrackPoint = TrackPoint();
      return;
    }
    // min length
    if (_trackPoints.length < 5) return;
    // max length
    while (_trackPoints.length > 100) {
      _trackPoints.removeAt(0);
    }

    List<TrackPoint> trackList = _recentTracks();
    // skip if nothing was found
    if (trackList.isEmpty) return;

    if (_status == statusStop) {
      if (_checkMoved(trackList)) {
        start(trackList.first);
        return;
      }
    } else {
      if (_checkStopped(trackList)) {
        stop(TrackPoint());
        return;
      }
    }
  }

  static double movedDistance() {
    List<GPS> tracks = [];
    for (var i in _trackPoints) {
      if (i.gpsOk) tracks.add(i.gps);
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
  static void _track() {
    if (!_tracking) return;
    Future.delayed(tickTime, () {
      _checkStatus();
      _track();
    });
  }

  /// start tracking heartbeat
  static void startTracking() {
    if (_tracking) return;
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
