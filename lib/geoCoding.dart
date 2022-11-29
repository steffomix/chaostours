import 'logger.dart' show log;
import 'dart:math' show sqrt, pow;
import 'geoLocation.dart' show GPSLookup;
import 'package:geolocator/geolocator.dart' show Position;
import 'package:sprintf/sprintf.dart' show sprintf;
import 'package:http/http.dart' as http;
import 'dart:async' show Timer;

class TrackingStatusChangedEvent {
  final TrackingStatus status;
  final TrackPoint trackpointStart;
  final TrackPoint trackPointEnd;
  final Address address;

  TrackingStatusChangedEvent(
      this.status, this.trackpointStart, this.trackPointEnd, this.address);
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
  static int _id = 0;
  int id = _id;
  static const Duration trackingTickTime = Duration(seconds: 1);
  DateTime _time = DateTime.now();
  static bool _tracking = false;
  static final List<TrackPoint> _tracklist = [];
  //
  static const int timeDifference = 15; // in minutes
  static const double locationDifference = 0.00145 * 5; // 0.00145 = ~100m
  static TrackingStatus _status = TrackingStatus.stop();
  static Function(TrackingStatusChangedEvent) _statusCallback = (t) {
    log('TrackingStatusEvent ${t.address.asString}');
  };

  static TrackingStatus get status {
    return _status;
  }

  static bool get tracking {
    return _tracking;
  }

  DateTime get time {
    return _time;
  }

  /// set status changed callback
  TrackPoint.init(Function(TrackingStatusChangedEvent) cb) {
    _statusCallback = cb;
  }

  static double latDebug = 0;
  static double lonDebug = 0;

  static void move() {
    latDebug += locationDifference;
    lonDebug -= locationDifference;
  }

  ///
  TrackPoint() {
    _id++;
    Timer(const Duration(seconds: 1), () {
      lat = latDebug;
      lon = lonDebug;
      _time = DateTime.now();
      _gpsOk = true;
      log('$lat, $lon');
      _tracklist.add(this);
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

  void _setStatus(TrackingStatus status, TrackPoint t1, TrackPoint t2) {
    _status = status;
    t1.lookupGPS().then((Address addr) {
      _statusCallback(TrackingStatusChangedEvent(status, t1, t2, address));
    });
  }

  /// check movement in last timeDifference was more than 0.015 gps degree or ~100m
  void checkStatus() {
    // prune _tracklist
    if (_tracklist.length < 10) {
      _status = TrackingStatus.stop();
      return;
    }
    while (_tracklist.length > 100) {
      _tracklist.removeAt(0);
    }

    // find first track with gps
    TrackPoint t1 = _tracklist.last;
    TrackPoint t2 = t1;
    int index = _tracklist.length;
    for (var i = _tracklist.length - 1; i < 0; i--) {
      if (_tracklist[i]._gpsOk == true) {
        t1 = _tracklist[i];
        index = i - 1;
        break;
      }
    }
    // go at least <timeDifference> back and pick next
    for (var i = index - 1; i >= 0; i--) {
      if (_tracklist[i]._gpsOk == true &&
          t1._time.difference(_tracklist[i]._time).inSeconds >=
              timeDifference) {
        t2 = _tracklist[i];
        log('${_tracklist[i]._time.difference(t1._time).inSeconds}');
        break;
      }
    }
    // calculate distance between both points
    // 0.00145 gps degree = ~100m
    double dist = distance(t1, t2);

    if (_status.status == TrackingStatus.statusStop &&
        dist > locationDifference) {
      // status changed from stop to move
      _setStatus(TrackingStatus.move(), t1, t2);
    }

    if (_status.status == TrackingStatus.statusMove &&
        dist < locationDifference) {
      // status changed from move to stop
      _setStatus(TrackingStatus.stop(), t1, t2);
    }
    log('t1.id: ${t1.id} - ${t1.lat} || t2.id: ${t2.id} - ${t2.lat}');
  }

  double distance(TrackPoint t1, TrackPoint t2) {
    double dist = sqrt(pow(t1.lat - t2.lat, 2) + pow(t1.lon - t2.lon, 2));
    log('gps distance $dist');
    return dist;
  }

  static Future<void> _track() async {
    if (!_tracking) return;
    Future.delayed(trackingTickTime, () {
      log('_track');
      TrackPoint();
      _track();
    });
  }

  static void startTracking() {
    if (_tracking) return;
    log('start tracking');
    _tracking = true;
    _track();
  }

  static void stopTracking() {
    if (!_tracking) return;
    log('stop tracking');
    _tracking = false;
  }
}

class GPS {
  double lat = 0;
  double lon = 0;
  bool _gpsOk = false;
  bool _addressOk = false;
  bool gps = false;
  Address _address = Address.empty();

  GPS();

  Address get address {
    return _address;
  }

  // lookup geo location on openstreetmap.org
  Future<Address> lookupGPS() async {
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

      _addressOk = true;
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
