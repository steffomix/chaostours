import 'package:chaostours/globals.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/app_settings.dart';
import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/background_process/trackpoint.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    Logger.backgroundLogger = true;
    Logger.prefix = '~~';
    Logger.logLevel = LogLevel.verbose;
    final Logger logger = Logger.logger<BackgroundTracking>();
    try {
      logger.log('load app settings');

      /// load app settings
      AppSettings.load();
      FileHandler().getStorage();
      logger.log(
          'using storage ${Globals.storageKey.name}::${Globals.storagePath}');

      FileHandler.logger.important('Start background tracking task');
      await TrackPoint().startShared();
      logger.important('Start background tracking task');
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
  });
}

class BackgroundTracking {
  static final Logger logger = Logger.logger<BackgroundTracking>();
  static int counter = 0;
  static bool _isTracking = false;

  static AndroidConfig config() {
    return AndroidConfig(
        channelName: 'Chaos Tours Background Tracking',
        notificationBody:
            'Background Tracking running, tap to open Chaos Tours App.',
        notificationIcon: 'drawable/explore',
        enableNotificationLocationUpdates: false,
        cancelTrackingActionText: 'Stop Tracking',
        enableCancelTrackingAction: true,
        trackingInterval: Globals.trackPointInterval,
        distanceFilterMeters: 0.0);
  }

  /// returns the current status without checking
  static bool get tracking => _isTracking;

  static Future<bool> isTracking() async {
    _isTracking = await BackgroundLocationTrackerManager.isTracking();
    return _isTracking;
  }

  static Future<void> startTracking() async {
    await AppSettings.load();

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
