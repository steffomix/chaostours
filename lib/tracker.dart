import 'logger.dart';
import 'trackPoint.dart';

class Tracker {
  static bool _tracking = false;
  static const Duration _tickTime = Duration(seconds: 2);

  /// tracking heartbeat with <trackingTickTime> speed
  static Future<void> _track() async {
    if (!_tracking) return;
    Future.delayed(_tickTime, () {
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
