import 'logger.dart' show log, info, severe;
import 'dart:math' show sqrt, pow;
import 'package:geolocator/geolocator.dart'
    show Geolocator, Position, LocationPermission;
import 'package:sprintf/sprintf.dart' show sprintf;
import 'package:http/http.dart' as http;
import 'dart:async' show Timer;

class TrackingStatusChangedEvent {
  final TrackingStatus status;
  final TrackPoint trackPoint;
  final Duration duration;

  TrackingStatusChangedEvent(this.status, this.trackPoint, this.duration);
}

class TrackingStatus {
  static const int statusStop = 0;
  static const int statusMove = 1;
  int _status = 0;

  TrackingStatus.stop() {
    _status = statusStop;
  }

  TrackingStatus.move() {
    _status = statusMove;
  }

  int get status {
    return _status;
  }
}

class TrackPoint extends GPS {
  static int _nextTrackPointId = 0;
  final int _trackPointId = ++TrackPoint._nextTrackPointId - 1;
  //
  static const Duration trackingTickTime = Duration(seconds: 1);
  DateTime _trackPointTime = DateTime.now();
  static bool _tracking = false;
  static final List<TrackPoint> _trackRecords = [];

  // time in minutes between two gps point to measure
  static const int timeTreshold = 15; // in minutes
  // distance in gps degree between two gps points (0.00145deg =  ~100m)
  static const double distanceTreshold = 0.00145 * 5;
  // status on app start
  static TrackingStatus _status = TrackingStatus.stop();
  // default status changed event handler
  static Function(TrackingStatusChangedEvent) _statusCallback = (e) {
    log('#########################TrackingStatusEvent################################\n'
        'Status ${e.status.status == 0 ? 'stop' : 'start'}\n'
        'Address ${e.trackPoint.address.asString}\n'
        'Duration ${e.duration.inDays} days, ${e.duration.inHours}:${e.duration.inMinutes}:${e.duration.inSeconds}\n'
        '###################');
  };

  // last Trackpoint that caused a status changed event
  static TrackPoint _lastStatusChangedTrackPoint = TrackPoint();

  // stop or move status
  static TrackingStatus get status {
    return _status;
  }

  // tracking is running
  static bool get tracking {
    return _tracking;
  }

  // time of gps snapshot
  DateTime get time {
    return _trackPointTime;
  }

  int get trackPointId {
    return _trackPointId;
  }

  TrackPoint get lastStatusChangedTrackPoint {
    return _lastStatusChangedTrackPoint;
  }

  /// set status changed callback
  TrackPoint.init(Function(TrackingStatusChangedEvent) cb) {
    _statusCallback = cb;
  }

  // 52.3267836449692, 9.188893435721065
  static double latDebug = 52.3267;
  static double lonDebug = 9.18889;

  static void move() {
    latDebug += distanceTreshold / 10;
    lonDebug -= distanceTreshold / 10;
  }

  ///
  TrackPoint() {
    Timer(const Duration(seconds: 1), () {
      lat = latDebug;
      lon = lonDebug;
      _trackPointTime = DateTime.now();
      _gpsOk = true;
      // log('$lat, $lon');
      _trackRecords.add(this);
      checkStatus();
    });
    return;
    // GPSLookup.getPosition().then((Position p) {
    //   lat = p.latitude;
    //   lon = p.longitude;
    //   _time = DateTime.now();
    //   _gpsOk = true;
    // }).onError((error, stackTrace) {
    //   log('GPSLookup failed: ${error.toString()}');
    // });
    // _tracklist.add(this);
    // checkStatus();
  }

  /// calculate duration of last status and set new status
  void _setStatus(TrackingStatus newStatus, TrackPoint trackPoint) {
    // get duration of last status
    Duration duration =
        trackPoint.time.difference(_lastStatusChangedTrackPoint.time);
    // set new status
    _status = newStatus;
    _trackRecords.clear();
    // lookup address from gps and trigger status changed event
    trackPoint.lookupAddress().then((Address addr) {
      _statusCallback(TrackingStatusChangedEvent(status, trackPoint, duration));
    }).onError((error, stackTrace) {
      severe('lookupAddress failed on gps ID ${trackPoint.gpsId}');
    });
  }

  checkStatus() {
    // don't even try any status detection
    //under a certain amount of records
    // prune old records
    while (_trackRecords.length > 100) {
      _trackRecords.removeAt(0);
    }

    // find first track with gpsOk
    TrackPoint t1 = _trackRecords.last;
    TrackPoint t2 = t1;
    int index = _trackRecords.length - 2;
    for (var i = index; i > 0; i--) {
      if (_trackRecords[i]._gpsOk == true) {
        t1 = _trackRecords[i];
        index = i - 1;
        break;
      }
    }
    // skip if no gpsOk was found
    if (t1 == t2) return;
    // go at least <timeDifference> back
    // and look for next gps with gpsOk
    int diff = 0;
    for (var i = index; i >= 0; i--) {
      diff = t1._trackPointTime
          .difference(_trackRecords[i]._trackPointTime)
          .inSeconds;
      if (_trackRecords[i]._gpsOk == true && diff >= timeTreshold) {
        t2 = _trackRecords[i];
        index = i;
        break;
      }
    }
    int st = _status.status;
    if (_status.status == TrackingStatus.statusStop) {
      if (distance(t1, t2) > distanceTreshold) {
        _setStatus(TrackingStatus.move(), t2);
      }
    } else {
      if (distance(t1, t2) <= distanceTreshold) {
        _setStatus(TrackingStatus.stop(), t2);
      }
      // check for stopping
    }
    //if (index > 0 && index < _trackRecords.length)
    //_trackRecords.removeRange(0, index);
  }

  /// check movement in last timeDifference was more than 0.015 gps degree or ~100m
  void ___checkStatus() {
    // don't even try any status detection
    //under a certain amount of records
    if (_trackRecords.length < 10) {
      _status = TrackingStatus.stop();
      return;
    }
    // prune old records
    while (_trackRecords.length > 100) {
      _trackRecords.removeAt(0);
    }

    // find first track with gpsOk
    TrackPoint t1 = _trackRecords.last;
    TrackPoint t2 = t1;
    int index = _trackRecords.length;
    for (var i = _trackRecords.length - 1; i < 0; i--) {
      if (_trackRecords[i]._gpsOk == true) {
        info('checkStatus: most recent gpsOk id: $_gpsId');
        t1 = _trackRecords[i];
        index = i - 1;
        break;
      }
    }
    // go at least <timeDifference> back
    // and look for next gps with gpsOk
    for (var i = index - 1; i >= 0; i--) {
      if (_trackRecords[i]._gpsOk == true &&
          t1._trackPointTime
                  .difference(_trackRecords[i]._trackPointTime)
                  .inSeconds >=
              timeTreshold) {
        t2 = _trackRecords[i];
        info('checkStatus: 5 minutes back gpsOk id: $_gpsId');
        index = i;
        break;
      }
    }

    // skip if nothing was found
    if (t1 == t2) return;

    // calculate distance between both points with <timeDifference> distance
    // 0.00145 gps degree = ~100m
    double dist = distance(t1, t2);
    info('deg distance between ${t1.gpsId} and ${t2.gpsId}: $dist');

    if (_status.status == TrackingStatus.statusStop &&
        dist > distanceTreshold) {
      info('change status to move on gpsId ${t2.gpsId} with distance $dist');
      // status changed from stop to move
      log('started at location with gpsId ${t2.gpsId}');
      _setStatus(TrackingStatus.move(), t2);
    }

    // stop detected, figure out when exactly we arrived at this location
    if (_status.status == TrackingStatus.statusMove &&
        dist < distanceTreshold) {
      info('change status to stop');
      TrackPoint t = _trackRecords.last;
      for (var i = _trackRecords.length - 2; i >= 0; i--) {
        if (distance(_trackRecords[i], t) > distanceTreshold) {
          t2 = _trackRecords[i + 1];
          log('stopped at location with gpsId ${t2.gpsId}');
          break;
        }
      }
      // status changed from move to stop
      _setStatus(TrackingStatus.stop(), t2);
    }
  }

  /// calculate distance between two gps points in plain degree
  double distance(TrackPoint t1, TrackPoint t2) {
    double dist = sqrt(pow(t1.lat - t2.lat, 2) + pow(t1.lon - t2.lon, 2));
    info('gps distance $dist');
    return dist;
  }

  /// calculate gps degree to km rounded to 3 decimal digits
  double distToKm(double dist) {
    return ((dist / distanceTreshold * 1000).round()) / 1000;
  }

  /// tracking heartbeat with <trackingTickTime> speed
  static Future<void> _track() async {
    if (!_tracking) return;
    Future.delayed(trackingTickTime, () {
      info('-------- next track ---------');
      TrackPoint();
      _track();
    });
  }

  /// start tracking heartbeat
  static void startTracking() {
    if (_tracking) return;
    info('start tracking');
    _tracking = true;
    _track();
  }

  /// stop tracking heartbeat
  static void stopTracking() {
    if (!_tracking) return;
    info('stop tracking');
    _tracking = false;
  }
}

class GPS {
  static int _nextGpsId = 0;
  final int _gpsId = ++GPS._nextGpsId - 1;
  double lat = 0;
  double lon = 0;
  bool _gpsOk = false;
  bool gps = false;
  Address _address = Address.empty();

  int get gpsId {
    return _gpsId;
  }

  GPS() {
    try {
      lookupGPS().then((p) {
        lat = p.latitude;
        lon = p.longitude;
        _gpsOk = true;
        //info('GPS id $_gpsId: lat: $lat, lon: $lon');
      }).onError((e, stackTrace) {
        severe('gps failed: ${e.toString()}');
      });
    } catch (e) {
      severe('gps failed: ${e.toString()}');
    }
  }

  Future<Position> lookupGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  Address get address {
    return _address;
  }

  // lookup geo location on openstreetmap.org
  Future<Address> lookupAddress() async {
    var url = Uri.https('nominatim.openstreetmap.org', '/reverse',
        {'lat': lat.toString(), 'lon': lon.toString()});
    var response = await http.get(url);
    if (response.statusCode == 200) {
      String body = response.body;
      String pattern = r'<%s>(.*)<\/%s>';
      String streetTag = 'road';
      String houseTag = 'house_number';
      String townTag = 'town';
      String postCodeTag = 'postcode';
      RegExp street = RegExp(sprintf(pattern, [streetTag, streetTag]));
      RegExp house = RegExp(sprintf(pattern, [houseTag, houseTag]));
      RegExp town = RegExp(sprintf(pattern, [townTag, townTag]));
      RegExp postCode = RegExp(sprintf(pattern, [postCodeTag, postCodeTag]));
      _address = Address(
          lat,
          lon,
          street.firstMatch(body)?.group(1) ?? '',
          house.firstMatch(body)?.group(1) ?? '',
          postCode.firstMatch(body)?.group(1) ?? '',
          town.firstMatch(body)?.group(1) ?? '');
    }
    return _address;
  }
}

class Address {
  final DateTime time = DateTime.now();
  final double lat;
  final double lon;
  final String street;
  final String house;
  final String code;
  final String town;
  Address(this.lat, this.lon, this.street, this.house, this.code, this.town);

  Address.empty()
      : lat = 0,
        lon = 0,
        street = '',
        house = '',
        code = '',
        town = '';

  String get asString {
    return '$street $house, $code $town';
  }
}

/*
  static final double _lat = 52.3367;
  static final double _lon = 9.21645353535;
  static double _latMod = 0;
  static double _lonMod = 0;

  void _testGps() {
    Future.delayed(const Duration(seconds: 3), () {
      if (Random().nextInt(10) > 6) {
        GPS._latMod = Random().nextDouble();
        GPS._lonMod = Random().nextDouble();
      }
      lat = GPS._lat + GPS._latMod;
      lon = GPS._lon + GPS._lonMod;

      // GeoCoding(this);
    });
  }
*/
