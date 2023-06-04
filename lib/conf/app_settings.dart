// ignore_for_file: unnecessary_getters_setters

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
import 'package:chaostours/conf/osm.dart';

enum SettingUnits {
  second(1),
  minute(60),
  meter(1),
  piece(1);

  final int multiplicator;
  const SettingUnits(this.multiplicator);
}

class AppSettingLimits {
  final CacheKeys cacheKey;
  final int? min;
  final int? max;
  final bool zeroDisables;
  final SettingUnits unit;

  AppSettingLimits(
      {required this.cacheKey,
      this.min,
      this.max,
      this.zeroDisables = false,
      this.unit = SettingUnits.second});

  bool isValid(num value) {
    return ((value == 0 && zeroDisables) || isBetween(value));
  }

  /// value >= min && value <= max
  bool isBetween(num value) {
    return (min == null ? true : value >= min!) &&
        (max == null ? true : value <= max!);
  }
}

class AppSettings {
  static int appTicks = 0;
  static final Logger logger = Logger.logger<AppSettings>();

  static String version = '0.0.1';

  /// german default short week names
  static const List<String> _weekDaysDefault = [
    '',
    'Mo',
    'Di',
    'Mi',
    'Do',
    'Fr',
    'Sa',
    'So'
  ];

  static List<String> _weekDays = _weekDaysDefault;
  static List<String> get weekDays => _weekDays;
  static set weekDays(List<String> value) {
    _weekDays = value;
  }

  /// user edit settings.
  /// All setting names must match enum AppSettings values in app_settings.dart
  /// if backgroundTracking is enabled and starts automatic
  static const bool _backgroundTrackingEnabledDefault = true;
  static bool _backgroundTrackingEnabled = _backgroundTrackingEnabledDefault;
  static bool get backgroundTrackingEnabled => _backgroundTrackingEnabled;
  static set backgroundTrackingEnabled(bool value) {
    _backgroundTrackingEnabled = value;
  }

  ///
  /// If true, status standing is triggered only if location has an alias.
  static const bool _statusStandingRequireAliasDefault = true;
  static bool _statusStandingRequireAlias = _statusStandingRequireAliasDefault;
  static bool get statusStandingRequireAlias => _statusStandingRequireAlias;
  static set statusStandingRequireAlias(bool value) {
    _statusStandingRequireAlias = value;
  }

  /// currently only used on live tracking page.
  /// Looks for new background data.
  static const Duration _backgroundLookupDurationDefault =
      Duration(seconds: 10);
  static Duration _backgroundLookupDuration = _backgroundLookupDurationDefault;
  static Duration get backgroundLookupDuration => _backgroundLookupDuration;
  static AppSettingLimits backgroundLookupDurationLimits = AppSettingLimits(
      cacheKey: CacheKeys.globalsBackgroundLookupDuration, min: 5, max: 60);
  static set backgroundLookupDuration(Duration value) {
    if (backgroundLookupDurationLimits.isValid(value.inSeconds)) {
      _backgroundLookupDuration = value;
    }
  }

  /// User interactions can cause massive foreground gps lookups.
  /// to prevent application lags, gps is chached for some seconds
  static const Duration _cacheGpsTimeDefault = Duration(seconds: 10);
  static Duration _cacheGpsTime = _cacheGpsTimeDefault;
  static Duration get cacheGpsTime => _cacheGpsTime;
  static AppSettingLimits cachGpsTimeLimits = AppSettingLimits(
      cacheKey: CacheKeys.globalsCacheGpsTime, max: 600, zeroDisables: true);

  static set cacheGpsTime(Duration value) {
    if (cachGpsTimeLimits.isValid(value.inSeconds)) {
      _cacheGpsTime = value;
    }
  }

  /// the distance to travel within <timeRangeTreshold> to trigger a status change.
  /// Above to trigger moving, below to trigger standing
  /// This is also the default radius for new alias
  static const int _distanceTresholdDefault = 100; //meters
  static int _distanceTreshold = _distanceTresholdDefault;
  static int get distanceTreshold => _distanceTreshold;
  static AppSettingLimits distanceTresholdLimits = AppSettingLimits(
      cacheKey: CacheKeys.globalsDistanceTreshold,
      min: 10,
      unit: SettingUnits.meter);
  static set distanceTreshold(int value) {
    if (distanceTresholdLimits.isValid(value)) {
      _distanceTreshold = value;
    }
  }

  /// stop time needed to trigger stop.
  /// Shoud be at least 3 times more than trackPointDuration
  static const Duration _timeRangeTresholdDefault = Duration(seconds: 180);
  static Duration _timeRangeTreshold = _timeRangeTresholdDefault;
  static Duration get timeRangeTreshold => _timeRangeTreshold;
  static AppSettingLimits timeRangeTresholdLimits = AppSettingLimits(
      cacheKey: CacheKeys.globalsTimeRangeTreshold,
      min: (trackPointInterval.inSeconds * 3 / 60).ceil(),
      unit: SettingUnits.minute);
  static set timeRangeTreshold(Duration value) {
    if (timeRangeTresholdLimits.isValid(value.inSeconds) &&
        value.inSeconds >= trackPointInterval.inSeconds * 3) {
      _timeRangeTreshold = value;
    }
  }

  /// background interval.
  static const Duration _trackPointIntervalDefault = Duration(seconds: 30);
  static Duration _trackPointInterval = _trackPointIntervalDefault;
  static Duration get trackPointInterval => _trackPointInterval;
  static AppSettingLimits get trackPointIntervalLimits {
    return AppSettingLimits(
        cacheKey: CacheKeys.globalsTrackPointInterval,
        min: 15,
        max: (_timeRangeTreshold.inSeconds / 1).ceil());
  }

  static set trackPointInterval(Duration value) {
    if (trackPointIntervalLimits.isValid(value.inSeconds)) {
      _trackPointInterval = value;
    }
  }

  /// compensate unprecise gps by using average of given gpsPoints.
  /// That means that a smooth count of 3 requires at least 4 gpsPoints
  /// for trackpoint calculation
  static const int _gpsPointsSmoothCountDefault = 5;
  static int _gpsPointsSmoothCount = _gpsPointsSmoothCountDefault;
  static int get gpsPointsSmoothCount => _gpsPointsSmoothCount;
  static AppSettingLimits get gpsPointsSmoothCountLimits {
    return AppSettingLimits(
        cacheKey: CacheKeys.globalsGpsPointsSmoothCount,
        min: 2,
        max: (timeRangeTreshold.inSeconds / trackPointInterval.inSeconds)
            .floor(),
        zeroDisables: true,
        unit: SettingUnits.piece);
  }

  static set gpsPointsSmoothCount(int count) {
    if (gpsPointsSmoothCountLimits.isValid(count)) {
      _gpsPointsSmoothCount = count;
    }
  }

  static const bool _publishToCalendarDefault = false;
  static bool _publishToCalendar = _publishToCalendarDefault;
  static bool get publishToCalendar => _publishToCalendar;
  static set publishToCalendar(bool value) {
    _publishToCalendar = value;
  }

  /// when background looks for an address of given gps
  static const OsmLookupConditions _osmLookupConditionDefault =
      OsmLookupConditions.onStatus;
  static OsmLookupConditions _osmLookupCondition = _osmLookupConditionDefault;
  static OsmLookupConditions get osmLookupCondition => _osmLookupCondition;
  static set osmLookupCondition(OsmLookupConditions value) {
    _osmLookupCondition = value;
  }

  /// if no alias is found on trackingstatus standing
  /// how long in minutes to wait until an alias is autocreated
  /// 0 = disabled
  static const Duration _autocreateAliasDefault = Duration(minutes: 10);
  static Duration get autocreateAliasDefault => _autocreateAliasDefault;
  static Duration _autoCreateAlias = _autocreateAliasDefault;
  static Duration get autoCreateAlias => _autoCreateAlias;
  static AppSettingLimits autoCreateAliasLimits = AppSettingLimits(
      cacheKey: CacheKeys.globalsAutocreateAlias,
      min: 10,
      zeroDisables: true,
      unit: SettingUnits.minute);
  static set autoCreateAlias(Duration dur) {
    if (autoCreateAliasLimits.isValid(dur.inMinutes)) {
      _autoCreateAlias = dur;
    }
  }

  static Future<void> loadSettings() async {
    try {
      await Cache.reload();
      _statusStandingRequireAlias = await Cache.getValue<bool>(
          CacheKeys.globalsStatusStandingRequireAlias,
          _statusStandingRequireAliasDefault);

      _backgroundTrackingEnabled = await Cache.getValue<bool>(
          CacheKeys.globalsBackgroundTrackingEnabled,
          _backgroundTrackingEnabledDefault);

      _backgroundLookupDuration = await Cache.getValue<Duration>(
          CacheKeys.globalsBackgroundLookupDuration,
          _backgroundLookupDurationDefault);

      _cacheGpsTime = await Cache.getValue<Duration>(
          CacheKeys.globalsCacheGpsTime, _cacheGpsTimeDefault);

      _distanceTreshold = await Cache.getValue<int>(
          CacheKeys.globalsDistanceTreshold, _distanceTresholdDefault);

      _timeRangeTreshold = await Cache.getValue<Duration>(
          CacheKeys.globalsTimeRangeTreshold, _timeRangeTresholdDefault);

      _trackPointInterval = await Cache.getValue<Duration>(
          CacheKeys.globalsTrackPointInterval, _trackPointIntervalDefault);

      _gpsPointsSmoothCount = await Cache.getValue<int>(
          CacheKeys.globalsGpsPointsSmoothCount, _gpsPointsSmoothCountDefault);

      _osmLookupCondition = await Cache.getValue<OsmLookupConditions>(
          CacheKeys.globalsOsmLookupCondition, _osmLookupConditionDefault);

      /// processed value
      _autoCreateAlias = await Cache.getValue<Duration>(
          CacheKeys.globalsAutocreateAlias, _autocreateAliasDefault);

      _publishToCalendar = await Cache.getValue<bool>(
          CacheKeys.globalPublishToCalendar, _publishToCalendarDefault);
    } catch (e, stk) {
      logger.error('load settings: $e', stk);
    }
  }

  static Future<void> reset() async {
    _weekDays = _weekDaysDefault;
    _backgroundTrackingEnabled = _backgroundTrackingEnabledDefault;
    _statusStandingRequireAlias = _statusStandingRequireAliasDefault;
    _backgroundLookupDuration = _backgroundLookupDurationDefault;
    _cacheGpsTime = _cacheGpsTimeDefault;
    _distanceTreshold = _distanceTresholdDefault;
    _timeRangeTreshold = _timeRangeTresholdDefault;
    _trackPointInterval = _trackPointIntervalDefault;
    _gpsPointsSmoothCount = _gpsPointsSmoothCountDefault;
    _osmLookupCondition = _osmLookupConditionDefault;
    _autoCreateAlias = _autocreateAliasDefault;
    _publishToCalendar = _publishToCalendarDefault;
    await saveSettings();
  }

  static Future<bool> updateValue(
      {required CacheKeys key, required dynamic value}) async {
    if (value.runtimeType == int) {
      switch (key) {
        case CacheKeys.globalsBackgroundLookupDuration:
          backgroundLookupDuration = await Cache.setValue<Duration>(
              key, Duration(seconds: value as int));
          break;

        case CacheKeys.globalsCacheGpsTime:
          cacheGpsTime = await Cache.setValue<Duration>(
              key, Duration(seconds: value as int));
          break;

        case CacheKeys.globalsDistanceTreshold:
          distanceTreshold = await Cache.setValue<int>(key, value as int);
          break;

        case CacheKeys.globalsTimeRangeTreshold:
          timeRangeTreshold = await Cache.setValue<Duration>(
              key, Duration(seconds: value as int));
          break;

        case CacheKeys.globalsTrackPointInterval:
          trackPointInterval = await Cache.setValue<Duration>(
              key, Duration(seconds: value as int));
          break;

        case CacheKeys.globalsGpsPointsSmoothCount:
          gpsPointsSmoothCount = await Cache.setValue<int>(key, value as int);
          break;

        case CacheKeys.globalsAutocreateAlias:
          autoCreateAlias = await Cache.setValue<Duration>(
              key, Duration(seconds: value as int));
          break;

        default:
          logger.error('unsupportet key $key for type ${key.cacheType}',
              StackTrace.current);
          return false;
      }
    }
    if (key.cacheType == bool && value.runtimeType == key.cacheType) {
      switch (key) {
        case CacheKeys.globalsStatusStandingRequireAlias:
          statusStandingRequireAlias =
              await Cache.setValue<bool>(key, value as bool);
          return true;

        case CacheKeys.globalsBackgroundTrackingEnabled:
          backgroundTrackingEnabled =
              await Cache.setValue<bool>(key, value as bool);
          return true;

        case CacheKeys.globalPublishToCalendar:
          publishToCalendar = await Cache.setValue<bool>(key, value as bool);
          return true;

        default:
          logger.error('unsupportet key $key for type ${key.cacheType}',
              StackTrace.current);
          return false;
      }
    }
    if (key.cacheType == OsmLookupConditions &&
        value.runtimeType == key.cacheType) {
      osmLookupCondition = await Cache.setValue<OsmLookupConditions>(
          key, value as OsmLookupConditions);
      return true;
    }
    return false;
  }

  static Future<void> saveSettings() async {
    await Cache.setValue<bool>(
        CacheKeys.globalsBackgroundTrackingEnabled, backgroundTrackingEnabled);

    await Cache.setValue<bool>(CacheKeys.globalsStatusStandingRequireAlias,
        statusStandingRequireAlias);

    await Cache.setValue<Duration>(
        CacheKeys.globalsBackgroundLookupDuration, backgroundLookupDuration);

    await Cache.setValue<Duration>(CacheKeys.globalsCacheGpsTime, cacheGpsTime);

    await Cache.setValue<int>(
        CacheKeys.globalsDistanceTreshold, distanceTreshold);

    await Cache.setValue<Duration>(
        CacheKeys.globalsTimeRangeTreshold, timeRangeTreshold);

    await Cache.setValue<Duration>(
        CacheKeys.globalsTrackPointInterval, trackPointInterval);

    await Cache.setValue<int>(
        CacheKeys.globalsGpsPointsSmoothCount, gpsPointsSmoothCount);

    await Cache.setValue<OsmLookupConditions>(
        CacheKeys.globalsOsmLookupCondition, osmLookupCondition);

    await Cache.setValue<Duration>(
        CacheKeys.globalsAutocreateAlias, autoCreateAlias);

    await Cache.setValue<bool>(
        CacheKeys.globalPublishToCalendar, publishToCalendar);

    await Cache.reload();
  }
}
