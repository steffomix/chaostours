import 'geoCoding.dart' show GPS;
import 'locationAlias.dart' show LocationAlias;
import 'logger.dart' show log;

class GeoTracking {
  static bool _running = false;
  static const int _gpsLookupInterval = 3; // seconds
  static List<GPS> tracks = [];
  final Function(GPS) _callback;

  GeoTracking(this._callback);

  ///
  ///
  Future<void> _track() async {
    Future.delayed(const Duration(seconds: _gpsLookupInterval), () {
      log('_track');
      tracks.add(GPS(_callback));
      if (_running) {
        // _track();
      }
    });
  }

  void startTracking() {
    log('start tracking');
    if (_running) return;
    _running = true;
    _track();
  }

  void stopTracking() {
    log('stop tracking');
    if (!_running) return;
    _running = false;
  }
}
