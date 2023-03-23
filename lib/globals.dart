// ignore_for_file: prefer_const_constructors

enum OsmLookup { never, onStatus, always }

class Globals {
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

  // durations and distances
  // skip status check for given time to prevent mass actions
  static Duration waitTimeAfterStatusChanged = Duration(seconds: 15);

  /// the distance to travel within <timeRangeTreshold> to trigger a status change.
  /// Above to trigger moving, below to trigger standing
  static int distanceTreshold = 100; //meters

  /// stop time needed to trigger stop.
  /// Shoud be at least 3 times more than Globals.tickTrackPointDuration
  static Duration timeRangeTreshold = Duration(seconds: 120);

  /// check status interval.
  /// Should be at least 3 seconds due to GPS lookup needs at least 2 seconds
  static Duration trackPointInterval = Duration(seconds: 15);

  ///
  static OsmLookup osmLookupCondition = OsmLookup.onStatus;

  /// consumes mobile data!
  static Duration osmLookupInterval = Duration(seconds: 0);
}
