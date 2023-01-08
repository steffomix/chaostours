import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/shared.dart';

@pragma('vm:entry-point')
void backgroundCallback() {
  BackgroundLocationTrackerManager.handleBackgroundUpdated(
      (BackgroundLocationUpdateData data) async {
    Shared shared =
        Shared(key: SharedKeys.gps, data: '${data.lat},${data.lon}');
    Tracking.counter++;
    await shared.save();
  });
}

class Tracking {
  static int counter = 0;
  static EventManager eventManager = EventManager(Events.onGps);
  static Tracking? _instance;
  Tracking._() {
    initialize();
    Shared(key: SharedKeys.gps, data: '').observe(
        duration: const Duration(seconds: 1),
        fn: (String data) {
          List<String> parts = data.split(',');
          eventOnGps.fire(GPS(double.parse(parts[0]), double.parse(parts[1])));
        });
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
      logInfo('Tracking::startTracking: already tracking');
      return;
    }
    BackgroundLocationTrackerManager.startTracking(config: config());
    _isTracking = true;
  }

  void stopTracking() {
    if (!_isTracking) {
      logInfo('Tracking::stopTracking: already stopped');
      return;
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
