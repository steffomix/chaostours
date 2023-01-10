import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/shared.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    await Shared(SharedKeys.backgroundGps).save('${data.lat},${data.lon}');
  });
}

class Tracking {
  static int counter = 0;
  static Tracking? _instance;
  Tracking._() {
    initialize();
  }
  factory Tracking() => _instance ??= Tracking._();
  static bool _isTracking = false;

  static AndroidConfig config(
      {Duration duration = const Duration(seconds: 20)}) {
    return AndroidConfig(
        channelName: 'Chaos Tours Background Tracking',
        notificationBody:
            'Background Tracking running, tap to open Chaos Tours App.',
        notificationIcon: 'explore',
        enableNotificationLocationUpdates: false,
        cancelTrackingActionText: 'Stop Tracking',
        enableCancelTrackingAction: true,
        trackingInterval: duration,
        distanceFilterMeters: 0.0);
  }

  void startTracking() {
    if (_isTracking) {
      print('### Tracking::startTracking: already tracking');
      return;
    }
    BackgroundLocationTrackerManager.startTracking(config: config());
    _isTracking = true;
  }

  void stopTracking() {
    if (!_isTracking) {
      print('### Tracking::stopTracking: already stopped');
    }
    BackgroundLocationTrackerManager.stopTracking();
    _isTracking = false;
  }

  /// returns the current status without checking
  bool get tracking => _isTracking;

  Future<bool> isTracking() async {
    _isTracking = await BackgroundLocationTrackerManager.isTracking();
    return _isTracking;
  }

  Future<void> initialize() async {
    return await BackgroundLocationTrackerManager.initialize(
      backgroundCallback,
      config: BackgroundLocationTrackerConfig(
        loggingEnabled: true,
        androidConfig: config(),
        iOSConfig: const IOSConfig(
          activityType: ActivityType.FITNESS,
          distanceFilterMeters: null,
          restartAfterKill: true,
        ),
      ),
    );
  }
}
