import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:chaostours/logger.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    await Shared(SharedKeys.backgroundGps).save('${data.lat},${data.lon}');
  });
}

class Tracking {
  static Logger logger = Logger.logger<Tracking>();
  static int counter = 0;
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

  /// returns the current status without checking
  static bool get tracking => _isTracking;

  static Future<bool> isTracking() async {
    _isTracking = await BackgroundLocationTrackerManager.isTracking();
    return _isTracking;
  }

  static Future<void> startTracking() async {
    if (await isTracking() == true) {
      logger.warn(
          'start gps background tracking skipped: tracking already started');
      return;
    }
    logger.important('--START-- GPS background tracking');
    BackgroundLocationTrackerManager.startTracking(config: config());
    _isTracking = true;
  }

  static Future<void> stopTracking() async {
    if (await isTracking() == false) {
      logger.warn(
          'stop gps background tracking skipped: tracking already stopped');
      return;
    }
    logger.important('--STOP-- GPS background tracking');
    BackgroundLocationTrackerManager.stopTracking();
    _isTracking = false;
  }

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
