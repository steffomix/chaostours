/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// ignore_for_file: prefer_const_constructors
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';

enum OsmLookup { never, onStatus, always }

class _GlobalDefaults {
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

  /// User interactions can cause massive foreground gps lookups.
  /// to prevent application lags, gps is chached for some seconds
  static Duration cacheGpsTime = Duration(seconds: 10);

  /// the distance to travel within <timeRangeTreshold> to trigger a status change.
  /// Above to trigger moving, below to trigger standing
  /// This is also the default radius for new alias
  static int distanceTreshold = 150; //meters

  /// stop time needed to trigger stop.
  /// Shoud be at least 3 times more than Globals.tickTrackPointDuration
  static Duration timeRangeTreshold = Duration(seconds: 120);

  /// check status interval.
  /// Should be at least 3 seconds due to GPS lookup needs at least 2 seconds
  static Duration trackPointInterval = Duration(seconds: 5);

  /// compensate unprecise gps by using average of given gpsPoints.
  /// That means that a smooth count of 3 requires at least 4 gpsPoints
  /// for trackpoint calculation
  static int gpsPointsSmoothCount = 5;

  /// compensate unprecise impossible to reach gpsPoints
  /// by ignoring points that can't be reached under a maximum of speed
  /// in km/h (1 m/s = 3,6km/h = 2,23693629 miles/h)
  static int gpsMaxSpeed = 100;

  /// when background looks for an address of given gps
  static OsmLookup osmLookupCondition = OsmLookup.onStatus;

  // ignore: unused_element
  static Future<void> restoreDefaults() async {
    Globals.version = version;
    Globals.weekDays = weekDays;
    Globals.backgroundTrackingEnabled = backgroundTrackingEnabled;
    Globals.statusStandingRequireAlias = statusStandingRequireAlias;
    Globals.appTickDuration = appTickDuration;
    Globals.cacheGpsTime = cacheGpsTime;
    Globals.distanceTreshold = distanceTreshold;
    Globals.timeRangeTreshold = timeRangeTreshold;
    Globals.trackPointInterval = trackPointInterval;
    Globals.gpsPointsSmoothCount = gpsPointsSmoothCount;
    Globals.gpsMaxSpeed = gpsMaxSpeed;
    Globals.osmLookupCondition = osmLookupCondition;
  }
}

class Globals {
  static int appTicks = 0;
  static final Logger logger = Logger.logger<Globals>();

  static String version = _GlobalDefaults.version;
  static List<String> weekDays = _GlobalDefaults.weekDays;
  static bool backgroundTrackingEnabled =
      _GlobalDefaults.backgroundTrackingEnabled;
  static bool statusStandingRequireAlias =
      _GlobalDefaults.statusStandingRequireAlias;
  static Duration appTickDuration = _GlobalDefaults.appTickDuration;
  static Duration cacheGpsTime = _GlobalDefaults.cacheGpsTime;
  static int distanceTreshold = _GlobalDefaults.distanceTreshold;
  static Duration timeRangeTreshold = _GlobalDefaults.timeRangeTreshold;
  static Duration trackPointInterval = _GlobalDefaults.trackPointInterval;
  static int gpsPointsSmoothCount = _GlobalDefaults.gpsPointsSmoothCount;
  static int gpsMaxSpeed = _GlobalDefaults.gpsMaxSpeed;
  static OsmLookup osmLookupCondition = _GlobalDefaults.osmLookupCondition;

  static Future<void> loadSettings() async {
    try {
      statusStandingRequireAlias = await Cache.getValue<bool>(
          CacheKeys.globalsStatusStandingRequireAlias, false);

      backgroundTrackingEnabled = await Cache.getValue<bool>(
          CacheKeys.globalsBackgroundTrackingEnabled, false);

      appTickDuration = await Cache.getValue<Duration>(
          CacheKeys.globalsAppTickDuration, Duration(seconds: 1));

      cacheGpsTime = await Cache.getValue<Duration>(
          CacheKeys.globalsCacheGpsTime, Duration(seconds: 10));

      distanceTreshold =
          await Cache.getValue<int>(CacheKeys.globalsDistanceTreshold, 150);

      timeRangeTreshold = await Cache.getValue<Duration>(
          CacheKeys.globalsTimeRangeTreshold, Duration(seconds: 120));

      trackPointInterval = await Cache.getValue<Duration>(
          CacheKeys.globalsTrackPointInterval, Duration(seconds: 20));

      gpsPointsSmoothCount =
          await Cache.getValue<int>(CacheKeys.globalsGpsPointsSmoothCount, 5);

      gpsMaxSpeed =
          await Cache.getValue<int>(CacheKeys.globalsGpsMaxSpeed, 150);

      osmLookupCondition = await Cache.getValue<OsmLookup>(
          CacheKeys.globalsOsmLookupCondition, OsmLookup.onStatus);
    } catch (e, stk) {
      logger.error('load settings: $e', stk);
    }
  }

  static Future<void> saveSettings() async {
    await Cache.setValue<bool>(
        CacheKeys.globalsBackgroundTrackingEnabled, backgroundTrackingEnabled);

    await Cache.setValue<bool>(CacheKeys.globalsStatusStandingRequireAlias,
        statusStandingRequireAlias);

    await Cache.setValue<Duration>(
        CacheKeys.globalsAppTickDuration, appTickDuration);

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
  }
}
