// ignore_for_file: prefer_const_constructors
import 'package:chaostours/app_hive.dart';
import 'package:chaostours/cache.dart';

enum OsmLookup { never, onStatus, always }

class Globals {
  static Future<void> savePreselectedUsers() async {
    Cache.setValue<List<int>>(
        CacheKeys.globalsPreselectedUsers, preselectedUsers.toList());
  }

  static Future<Set<int>> loadPreselectedUsers() async {
    preselectedUsers =
        (await Cache.getValue<List<int>>(CacheKeys.globalsPreselectedUsers, []))
            .toSet();
    return preselectedUsers;
  }

  static Future<void> loadSettings() async {
    statusStandingRequireAlias = await Cache.getValue<bool>(
        CacheKeys.globalsBackgroundTrackingEnabled, false);
    appTickDuration = await Cache.getValue<Duration>(
        CacheKeys.globalsAppTickDuration, Duration(seconds: 1));

    await loadPreselectedUsers();

    cacheGpsTime = await Cache.getValue<Duration>(
        CacheKeys.globalsCacheGpsTime, Duration(seconds: 10));

    distanceTreshold =
        await Cache.getValue<int>(CacheKeys.globalsDistanceTreshold, 100);

    timeRangeTreshold = await Cache.getValue<Duration>(
        CacheKeys.globalsTimeRangeTreshold, Duration(seconds: 20));

    trackPointInterval = await Cache.getValue<Duration>(
        CacheKeys.globalsTrackPointInterval, Duration(seconds: 30));

    gpsPointsSmoothCount =
        await Cache.getValue<int>(CacheKeys.globalsGpsPointsSmoothCount, 5);

    gpsMaxSpeed = await Cache.getValue<int>(CacheKeys.globalsGpsMaxSpeed, 150);

    osmLookupCondition = await Cache.getValue<OsmLookup>(
        CacheKeys.globalsOsmLookupCondition, OsmLookup.onStatus);

    osmLookupInterval = await Cache.getValue<Duration>(
        CacheKeys.globalsOsmLookupInterval, Duration(seconds: 3600));
  }

  static Future<void> saveSettings() async {
    await Cache.setValue<bool>(
        CacheKeys.globalsBackgroundTrackingEnabled, backgroundTrackingEnabled);

    await Cache.setValue<Duration>(
        CacheKeys.globalsAppTickDuration, appTickDuration);

    savePreselectedUsers();

    await Cache.setValue<Duration>(CacheKeys.globalsCacheGpsTime, cacheGpsTime);

    await Cache.setValue<int>(
        CacheKeys.globalsDistanceTreshold, distanceTreshold);

    await Cache.setValue<Duration>(
        CacheKeys.globalsTimeRangeTreshold, timeRangeTreshold);

    await Cache.setValue<Duration>(
        CacheKeys.globalsTrackPointInterval, trackPointInterval);

    await Cache.setValue<int>(
        CacheKeys.globalsGpsPointsSmoothCount, gpsPointsSmoothCount);

    await Cache.setValue<int>(CacheKeys.globalsGpsMaxSpeed, gpsMaxSpeed);

    await Cache.setValue<OsmLookup>(
        CacheKeys.globalsOsmLookupCondition, osmLookupCondition);

    await Cache.setValue<Duration>(
        CacheKeys.globalsOsmLookupInterval, osmLookupInterval);
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
