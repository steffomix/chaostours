import 'package:background_location_tracker/background_location_tracker.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {});
}

class BackgroundTracking {
  static int counter = 0;
  static bool _isTracking = false;

  static AndroidConfig config() {
    return const AndroidConfig(
        channelName: 'Chaos Tours Background Tracking',
        notificationBody:
            'Background Tracking running, tap to open Chaos Tours App.',
        notificationIcon: 'drawable/explore',
        enableNotificationLocationUpdates: false,
        cancelTrackingActionText: 'Stop Tracking',
        enableCancelTrackingAction: true,
        trackingInterval: Duration(seconds: 30),
        distanceFilterMeters: 0.0);
  }

  /// returns the current status without checking
  static bool get tracking => _isTracking;

  static Future<bool> isTracking() async {
    _isTracking = await BackgroundLocationTrackerManager.isTracking();
    return _isTracking;
  }

  static Future<void> startTracking() async {
    BackgroundLocationTrackerManager.startTracking(config: config());
    _isTracking = true;
  }

  static Future<void> stopTracking() async {
    if (await isTracking() == false) {
      BackgroundLocationTrackerManager.stopTracking();
      _isTracking = false;
    }
  }

  ///
  static Future<void> initialize() async {
    await BackgroundLocationTrackerManager.initialize(
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
