// ignore_for_file: prefer_const_constructors
import 'package:chaostours/app_hive.dart';

enum OsmLookup { never, onStatus, always }

class Globals {
  static Future<void> loadSettings() async {
    await AppHive.accessBox(
        boxName: AppHiveNames.globalsAppSettings,
        access: (AppHive box) async {
          //
          statusStandingRequireAlias = box.read<bool>(
              hiveKey: AppHiveKeys.globalsBackgroundTrackingEnabled,
              value: false);
          //
          appTickDuration = box.read<Duration>(
              hiveKey: AppHiveKeys.globalsAppTickDuration,
              value: Duration(seconds: 3));
          //
          preselectedUsers = box.read<Set<int>>(
              hiveKey: AppHiveKeys.globalsPreselectedUsers, value: <int>{});
          //
          cacheGpsTime = box.read<Duration>(
              hiveKey: AppHiveKeys.globalsCacheGpsTime,
              value: Duration(seconds: 10));
          //
          distanceTreshold = box.read<int>(
              hiveKey: AppHiveKeys.globalsDistanceTreshold, value: 100);
          //
          timeRangeTreshold = box.read<Duration>(
              hiveKey: AppHiveKeys.globalsTimeRangeTreshold,
              value: Duration(seconds: 120));
          //
          trackPointInterval = box.read<Duration>(
              hiveKey: AppHiveKeys.globalsTrackPointInterval,
              value: Duration(seconds: 30));
          //
          gpsPointsSmoothCount = box.read<int>(
              hiveKey: AppHiveKeys.globalsGpsPointsSmoothCount, value: 5);
          //
          gpsMaxSpeed = box.read<int>(
              hiveKey: AppHiveKeys.globalsGpsMaxSpeed, value: 150);
          //
          osmLookupCondition = box.read<OsmLookup>(
              hiveKey: AppHiveKeys.globalsOsmLookupCondition,
              value: OsmLookup.onStatus);
          //
          osmLookupInterval = box.read<Duration>(
              hiveKey: AppHiveKeys.globalsGsmLookupInterval,
              value: Duration(minutes: 0));
        });
  }

  static Future<void> saveSettings() async {
    await AppHive.accessBox(
        boxName: AppHiveNames.globalsAppSettings,
        access: (AppHive box) async {
          //
          box.write<bool>(
              hiveKey: AppHiveKeys.globalsBackgroundTrackingEnabled,
              value: backgroundTrackingEnabled);
          //
          box.write<Duration>(
              hiveKey: AppHiveKeys.globalsAppTickDuration,
              value: appTickDuration);
          //
          box.write<Set<int>>(
              hiveKey: AppHiveKeys.globalsPreselectedUsers,
              value: preselectedUsers);
          //
          box.write<Duration>(
              hiveKey: AppHiveKeys.globalsCacheGpsTime, value: cacheGpsTime);
          //
          box.write<int>(
              hiveKey: AppHiveKeys.globalsDistanceTreshold,
              value: distanceTreshold);
          //
          box.write<Duration>(
              hiveKey: AppHiveKeys.globalsTimeRangeTreshold,
              value: timeRangeTreshold);
          //
          box.write<Duration>(
              hiveKey: AppHiveKeys.globalsTrackPointInterval,
              value: trackPointInterval);
          //
          box.write<int>(
              hiveKey: AppHiveKeys.globalsGpsPointsSmoothCount,
              value: gpsPointsSmoothCount);
          //
          box.write<int>(
              hiveKey: AppHiveKeys.globalsGpsMaxSpeed, value: gpsMaxSpeed);
          //
          box.write<OsmLookup>(
              hiveKey: AppHiveKeys.globalsOsmLookupCondition,
              value: OsmLookup.onStatus);
          //
          box.write<Duration>(
              hiveKey: AppHiveKeys.globalsGsmLookupInterval,
              value: osmLookupInterval);
        });
  }

  static String version = '1.0';

  /// german default short week names
  static List<String> weekDays = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  /// user edit settings.
  /// All setting names must match enum AppSettings values in app_settings.dart
  /// if backgroundTracking is enabled and starts automatic
  static bool backgroundTrackingEnabled = true;

  ///
  /// If true, status standing is triggered only if location has an alias.
  static bool statusStandingRequireAlias = true;

  /// currently only used on live tracking page.
  /// Looks for new background data.
  static Duration appTickDuration = Duration(seconds: 3);

  /// Users who are on preselected for chaostours
  static Set<int> preselectedUsers = {};

  /// User interactions can cause massive foreground gps lookups.
  /// to prevent application lags, gps is chached for some seconds
  static Duration cacheGpsTime = Duration(seconds: 5);

  /// the distance to travel within <timeRangeTreshold> to trigger a status change.
  /// Above to trigger moving, below to trigger standing
  static int distanceTreshold = 100; //meters

  /// stop time needed to trigger stop.
  /// Shoud be at least 3 times more than Globals.tickTrackPointDuration
  static Duration timeRangeTreshold = Duration(seconds: 120);

  /// check status interval.
  /// Should be at least 3 seconds due to GPS lookup needs at least 2 seconds
  static Duration trackPointInterval = Duration(seconds: 30);

  /// compensate unprecise gps by using average of given gpsPoints.
  /// That means that a smooth count of 3 requires at least 4 gpsPoints
  /// for trackpoint calculation
  static int gpsPointsSmoothCount = 5;

  /// compensate unprecise impossible to reach gpsPoints
  /// by ignoring points that can't be reached under a maximum of speed
  /// in km/h (1 m/s = 3,6km/h = 2,23693629 miles/h)
  static int gpsMaxSpeed = 150;

  /// when background looks for an address of given gps
  static OsmLookup osmLookupCondition = OsmLookup.onStatus;

  /// consumes mobile data!
  ///
  static Duration osmLookupInterval = Duration(seconds: 0);
}
