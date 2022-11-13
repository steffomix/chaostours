import 'dart:async';
import 'dart:core';
import 'dart:math';

class GPS {
  final double lat;
  final double lon;

  GPS(this.lat, this.lon);
}

class GeoLocation {
  bool _running = false;
  final int delay = 10; // seconds
  static String _intervalId = '';
  static List<GPS> tracks;

  final double _lat = 52.3367;
  final double _lon = 9.21645353535;
  double _latMod = 0;
  double _lonMod = 0;

  // create test gps
  GPS gps() {
    if (Random().nextInt(10) > 8) {
      _latMod = Random().nextDouble();
      _lonMod = Random().nextDouble();
    }

    var gps = GPS(_lat + _latMod, _lon + _lonMod);

    return gps;
  }

  void _track() {
    Future.delayed(const Duration(seconds: 2), () {
      GPS loc = gps();
      tracks.add(loc);
      print('_track ${loc.lat}, ${loc.lon}');
      if (_running) {
        _track();
      }
    });
  }

  void startTracking() {
    if (_running) return;
    _running = true;
    _track();
  }

  void stopTracking() {
    if (!_running) return;
    _running = false;
  }
}
