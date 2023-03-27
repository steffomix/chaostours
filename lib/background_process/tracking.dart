import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/globals.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    await TrackPoint().startShared(lat: data.lat, lon: data.lon);
  });
}

class BackgroundTracking {
  static bool _initialized = false;

  static AndroidConfig _androidConfig() {
    return AndroidConfig(
        channelName: 'Chaos Tours Background Tracking',
        notificationBody:
            'Background Tracking running, tap to open Chaos Tours App.',
        notificationIcon: 'drawable/explore',
        enableNotificationLocationUpdates: false,
        cancelTrackingActionText: 'Stop Tracking',
        enableCancelTrackingAction: true,
        trackingInterval: Globals.trackPointInterval);
  }

  static Future<bool> isTracking() async {
    return await BackgroundLocationTrackerManager.isTracking();
  }

  static Future<void> startTracking() async {
    if (!_initialized) {
      await initialize();
    }
    if (!await isTracking()) {
      BackgroundLocationTrackerManager.startTracking(config: _androidConfig());
    }
  }

  static Future<void> stopTracking() async {
    if (await isTracking()) {
      await BackgroundLocationTrackerManager.stopTracking();
    }
  }

  ///
  static Future<void> initialize() async {
    await BackgroundLocationTrackerManager.initialize(backgroundCallback);
    _initialized = true;
  }
}
