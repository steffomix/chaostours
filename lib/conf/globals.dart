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

class Globals {
  static int appTicks = 0;
  static final Logger logger = Logger.logger<Globals>();

  static String version = '0.0.1';

  /// german default short week names
  static const List<String> _weekDays = [
    '',
    'Mo',
    'Di',
    'Mi',
    'Do',
    'Fr',
    'Sa',
    'So'
  ];

  static List<String> weekDays = _weekDays;

  /// user edit settings.
  /// All setting names must match enum AppSettings values in app_settings.dart
  /// if backgroundTracking is enabled and starts automatic
  static const bool _backgroundTrackingEnabledDefault = true;
  static bool backgroundTrackingEnabled = _backgroundTrackingEnabledDefault;

  ///
  /// If true, status standing is triggered only if location has an alias.
  static const bool _statusStandingRequireAliasDefault = true;
  static bool statusStandingRequireAlias = _statusStandingRequireAliasDefault;

  /// currently only used on live tracking page.
  /// Looks for new background data.
  static const Duration _appTickDurationDefault = Duration(seconds: 1);
  static Duration appTickDuration = _appTickDurationDefault;

  /// User interactions can cause massive foreground gps lookups.
  /// to prevent application lags, gps is chached for some seconds
  static const Duration _cacheGpsTimeDefault = Duration(seconds: 10);
  static Duration cacheGpsTime = _cacheGpsTimeDefault;

  /// the distance to travel within <timeRangeTreshold> to trigger a status change.
  /// Above to trigger moving, below to trigger standing
  /// This is also the default radius for new alias
  static const int _distanceTresholdDefault = 100; //meters
  static int distanceTreshold = _distanceTresholdDefault;

  /// stop time needed to trigger stop.
  /// Shoud be at least 3 times more than Globals.tickTrackPointDuration
  static const Duration _timeRangeTresholdDefault = Duration(seconds: 180);
  static Duration timeRangeTreshold = _timeRangeTresholdDefault;

  /// check status interval.
  /// Should be at least 3 seconds due to GPS lookup needs at least 2 seconds
  static const Duration _trackPointIntervalDefault = Duration(seconds: 30);
  static Duration trackPointInterval = _trackPointIntervalDefault;

  /// compensate unprecise gps by using average of given gpsPoints.
  /// That means that a smooth count of 3 requires at least 4 gpsPoints
  /// for trackpoint calculation
  static const int _gpsPointsSmoothCountDefault = 5;
  static int _gpsPointsSmoothCount = _gpsPointsSmoothCountDefault;

  static int get gpsPointsSmoothCount => _gpsPointsSmoothCount;
  static set gpsPointsSmoothCount(int count) {
    if (count >= timeRangeTreshold.inSeconds / trackPointInterval.inSeconds) {
      _gpsPointsSmoothCount =
          (timeRangeTreshold.inSeconds / trackPointInterval.inSeconds).floor();
    } else {
      _gpsPointsSmoothCount = count;
    }
  }

  static const bool _publishToCalendarDefault = false;
  static bool publishToCalendar = _publishToCalendarDefault;

  /// compensate unprecise impossible to reach gpsPoints
  /// by ignoring points that can't be reached under a maximum of speed
  /// in km/h (1 m/s = 3,6km/h = 2,23693629 miles/h)
  static const int _gpsMaxSpeedDefault = 200;
  static int gpsMaxSpeed = _gpsMaxSpeedDefault;

  /// when background looks for an address of given gps
  static const OsmLookup _osmLookupConditionDefault = OsmLookup.onStatus;
  static OsmLookup osmLookupCondition = _osmLookupConditionDefault;

  /// if no alias is found on trackingstatus standing
  /// how long in minutes to wait until an alias is autocreated
  /// 0 = disabled
  static const Duration _autocreateAliasDefault = Duration(minutes: 10);
  static Duration _autoCreateAlias = _autocreateAliasDefault;
  //
  static Duration get autoCreateAlias => _autoCreateAlias;
  static set autoCreateAlias(Duration dur) {
    var old = _autoCreateAlias.inSeconds;
    var secs = dur.inSeconds;
    if (secs > 0) {
      var min = timeRangeTreshold.inSeconds * 2;
      if (min > secs) {
        _autoCreateAlias = Duration(seconds: min);
      } else {
        _autoCreateAlias = dur;
      }
    } else {
      // deactivate future
      _autoCreateAlias = Duration();
    }
  }

  static Future<void> loadSettings() async {
    try {
      statusStandingRequireAlias = await Cache.getValue<bool>(
          CacheKeys.globalsStatusStandingRequireAlias,
          _statusStandingRequireAliasDefault);

      backgroundTrackingEnabled = await Cache.getValue<bool>(
          CacheKeys.globalsBackgroundTrackingEnabled,
          _backgroundTrackingEnabledDefault);

      appTickDuration = await Cache.getValue<Duration>(
          CacheKeys.globalsAppTickDuration, _appTickDurationDefault);

      cacheGpsTime = await Cache.getValue<Duration>(
          CacheKeys.globalsCacheGpsTime, _cacheGpsTimeDefault);

      distanceTreshold = await Cache.getValue<int>(
          CacheKeys.globalsDistanceTreshold, _distanceTresholdDefault);

      timeRangeTreshold = await Cache.getValue<Duration>(
          CacheKeys.globalsTimeRangeTreshold, _timeRangeTresholdDefault);

      trackPointInterval = await Cache.getValue<Duration>(
          CacheKeys.globalsTrackPointInterval, _trackPointIntervalDefault);

      gpsPointsSmoothCount = await Cache.getValue<int>(
          CacheKeys.globalsGpsPointsSmoothCount, _gpsPointsSmoothCountDefault);

      gpsMaxSpeed = await Cache.getValue<int>(
          CacheKeys.globalsGpsMaxSpeed, _gpsMaxSpeedDefault);

      osmLookupCondition = await Cache.getValue<OsmLookup>(
          CacheKeys.globalsOsmLookupCondition, _osmLookupConditionDefault);

      autoCreateAlias = await Cache.getValue<Duration>(
          CacheKeys.globalsAutocreateAlias, _autocreateAliasDefault);

      publishToCalendar = await Cache.getValue<bool>(
          CacheKeys.globalPublishToCalendar, _publishToCalendarDefault);
    } catch (e, stk) {
      logger.error('load settings: $e', stk);
    }
  }

  static Future<void> reset() async {
    weekDays = _weekDays;
    backgroundTrackingEnabled = _backgroundTrackingEnabledDefault;
    statusStandingRequireAlias = _statusStandingRequireAliasDefault;
    appTickDuration = _appTickDurationDefault;
    cacheGpsTime = _cacheGpsTimeDefault;
    distanceTreshold = _distanceTresholdDefault;
    timeRangeTreshold = _timeRangeTresholdDefault;
    trackPointInterval = _trackPointIntervalDefault;
    gpsPointsSmoothCount = _gpsPointsSmoothCountDefault;
    gpsMaxSpeed = _gpsMaxSpeedDefault;
    osmLookupCondition = _osmLookupConditionDefault;
    autoCreateAlias = _autocreateAliasDefault;
    publishToCalendar = _publishToCalendarDefault;
    await saveSettings();
  }

  static Future<void> updateValue(
      {required CacheKeys key,
      required Type type,
      required dynamic value}) async {
    switch (key) {
      case CacheKeys.globalsAppTickDuration:
        appTickDuration = Duration(seconds: value as int);
        break;
      case CacheKeys.globalsCacheGpsTime:
        cacheGpsTime = Duration(seconds: value as int);
        break;

      case CacheKeys.globalsDistanceTreshold:
        distanceTreshold = value as int;
        break;

      case CacheKeys.globalsTimeRangeTreshold:
        timeRangeTreshold = Duration(seconds: value as int);
        break;

      case CacheKeys.globalsTrackPointInterval:
        trackPointInterval = Duration(seconds: value as int);
        break;
      case CacheKeys.globalsGpsPointsSmoothCount:
        gpsPointsSmoothCount = value as int;
        break;

      case CacheKeys.globalsGpsMaxSpeed:
        gpsMaxSpeed = value as int;
        break;

      case CacheKeys.globalsAutocreateAlias:
        autoCreateAlias = Duration(seconds: value as int);
        break;

      default:

      ///
    }
    await saveSettings();
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

    await Cache.getValue<Duration>(
        CacheKeys.globalsAutocreateAlias, autoCreateAlias);

    await Cache.setValue<bool>(
        CacheKeys.globalPublishToCalendar, publishToCalendar);

    await Cache.reload();
  }
}
