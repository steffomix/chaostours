import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/gps.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    eventOnGps.fire(GPS(data.lat, data.lon));
    return Future<void>.value();
  }); //(data) async => Repo().update(data),
}

class Tracking {
  static bool _isTracking = false;

  static AndroidConfig config(
      {Duration duration = const Duration(seconds: 10)}) {
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

  static void startTracking() {
    if (_isTracking) {
      logInfo('Tracking::startTracking: already tracking');
      return;
    }
    BackgroundLocationTrackerManager.startTracking(config: config());
    _isTracking = true;
  }

  static void stopTracking() {
    if (!_isTracking) {
      logInfo('Tracking::stopTracking: already stopped');
      return;
    }
    BackgroundLocationTrackerManager.stopTracking();
    _isTracking = false;
  }

  /// returns the current status without checking
  static bool get tracking => _isTracking;

  static Future<bool> isTracking() async {
    _isTracking = await BackgroundLocationTrackerManager.isTracking();
    return _isTracking;
  }

  static void initialize() async {
    return await BackgroundLocationTrackerManager.initialize(
      backgroundCallback,
      config: BackgroundLocationTrackerConfig(
        loggingEnabled: false,
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
