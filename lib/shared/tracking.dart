/*
import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/shared/shared.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/gps.dart';

Logger logger = Logger.logger<Tracking>();

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    logger.important(
        'execute background process with GPS: ${data.lat}, ${data.lon}');
    backgroundTask(GPS(data.lat, data.lon));
  });
}

Future<void> loadRunningTrackPoints() async {
  logger.important('load runningTrackPoints');
  Shared shared = Shared(SharedKeys.runningTrackpoints);
  List<String> tracks = await shared.loadList();

  logger.verbose('load runningTrackPoints: \n${tracks.join("\n")}');
  List<ModelTrackPoint> trackPoints = [];
  for (var row in tracks) {
    trackPoints.add(ModelTrackPoint.toSharedModel(row));
  }
  TrackPoint.runningTrackPoints.addAll(trackPoints);
}

void saveRunningTrackPoints() async {
  List<String> tracks = [];
  for (var tp in TrackPoint.runningTrackPoints) {
    tracks.add(tp.toSharedString());
  }

  Shared shared = Shared(SharedKeys.runningTrackpoints);
  logger.verbose('save runningTrackPoints: \n${tracks.join("\n")}');
  await shared.saveList(tracks);
}

Future<void> backgroundTask(GPS gps) async {
  // init logger
  Logger.backgroundLogger = true;
  Logger.prefix = '~~';
  Logger.logLevel = LogLevel.verbose;
  // database
  logger.log('Load Databases ModelTrackPoint, ModelAlias, ModelTask');
  try {
    await ModelTrackPoint.open();
    await ModelAlias.open();
    await ModelTask.open();
  } catch (e, stk) {
    logger.fatal(e.toString(), stk);
  }
  logger.log('loaded ModelTrackPoint with ${ModelTrackPoint.length} rows');
  logger.log('loaded ModelAlias with ${ModelAlias.length} rows');
  logger.log('loaded ModelTask with ${ModelTask.length} rows');
  logger.log('load running trackpoints');
  await loadRunningTrackPoints();
  logger
      .log('loaded ${TrackPoint.runningTrackPoints.length} runningTrackPoints');
  logger.log('start processing gps ${gps.toString()}');
  TrackPoint.trackPoint(EventOnGPS(gps));
  logger.log('processing gps finished, save running trackpoints');
  saveRunningTrackPoints();
  await Future.delayed(const Duration(seconds: 3));
}

class Tracking {
  static final Logger logger = Logger.logger<Tracking>();
  static int counter = 0;
  static bool _isTracking = false;

  static AndroidConfig config(
      {Duration duration = const Duration(seconds: 30)}) {
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
*/