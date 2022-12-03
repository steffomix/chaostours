///
/// file trackPoint.dart
///
/*
import 'trackingStatus.dart' show TrackingStatus;

class TrackPoint {
  static final List<TrackPoint> _trackPoints = [];

  void _addTrackPoint() {
    TrackPoint t2 = _trackPoints.last;

    // ...
    TrackingStatus.move(t2); // <-- compile error on t2
  }
}
*/