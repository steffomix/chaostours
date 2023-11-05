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

enum OsmLookupConditions { never, onStatus, always }

enum SettingUnits {
  second(1),
  minute(60),
  meter(1),
  piece(1);

  final int multiplicator;
  const SettingUnits(this.multiplicator);
}

class AppSettingLimits {
  final Cache cacheKey;
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
  static final Logger logger = Logger.logger<AppSettings>();

  static String version = '0.0.1';

  static const int defaultAliasGroupId = 1;

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

  static List<String> weekDays = _weekDaysDefault;

  static String timeZone = 'Europe/Berlin';

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
  static const Duration _backgroundLookupDurationDefault =
      Duration(seconds: 15);
  static Duration _backgroundLookupDuration = _backgroundLookupDurationDefault;
  static Duration get backgroundLookupDuration => _backgroundLookupDuration;
  static AppSettingLimits backgroundLookupDurationLimits = AppSettingLimits(
      cacheKey: Cache.globalsBackgroundLookupDuration, min: 5, max: 60);
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
      cacheKey: Cache.globalsCacheGpsTime, max: 600, zeroDisables: true);

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
      cacheKey: Cache.globalsDistanceTreshold,
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
  static set timeRangeTreshold(Duration value) {
    if (timeRangeTresholdLimits.isValid(value.inSeconds) &&
        value.inSeconds >= trackPointInterval.inSeconds * 3) {
      _timeRangeTreshold = value;
    }
  }

  static AppSettingLimits timeRangeTresholdLimits = AppSettingLimits(
      cacheKey: Cache.globalsTimeRangeTreshold,
      min: (trackPointInterval.inSeconds * 3 / 60).ceil(),
      unit: SettingUnits.minute);

  /// background interval.
  static const Duration _trackPointIntervalDefault = Duration(seconds: 30);
  static Duration _trackPointInterval = _trackPointIntervalDefault;
  static Duration get trackPointInterval => _trackPointInterval;
  static set trackPointInterval(Duration value) {
    if (trackPointIntervalLimits.isValid(value.inSeconds)) {
      _trackPointInterval = value;
    }
  }

  static AppSettingLimits get trackPointIntervalLimits {
    return AppSettingLimits(
        cacheKey: Cache.globalsTrackPointInterval,
        min: 15,
        max: (_timeRangeTreshold.inSeconds / 1).ceil());
  }

  /// compensate unprecise gps by using average of given gpsPoints.
  /// That means that a smooth count of 3 requires at least 4 gpsPoints
  /// for trackpoint calculation
  static const int _gpsPointsSmoothCountDefault = 5;
  static int _gpsPointsSmoothCount = _gpsPointsSmoothCountDefault;
  static int get gpsPointsSmoothCount => _gpsPointsSmoothCount;
  static set gpsPointsSmoothCount(int count) {
    if (gpsPointsSmoothCountLimits.isValid(count)) {
      _gpsPointsSmoothCount = count;
    }
  }

  static AppSettingLimits get gpsPointsSmoothCountLimits {
    return AppSettingLimits(
        cacheKey: Cache.globalsGpsPointsSmoothCount,
        min: 2,
        max: (timeRangeTreshold.inSeconds / trackPointInterval.inSeconds)
            .floor(),
        zeroDisables: true,
        unit: SettingUnits.piece);
  }

  static const bool _publishToCalendarDefault = true;
  static bool publishToCalendar = _publishToCalendarDefault;

  /// when background looks for an address of given gps
  static const OsmLookupConditions _osmLookupConditionDefault =
      OsmLookupConditions.onStatus;
  static OsmLookupConditions osmLookupCondition = _osmLookupConditionDefault;

  /// if no alias is found on trackingstatus standing
  /// how long in minutes to wait until an alias is autocreated
  /// 0 = disabled
  static const Duration _autocreateAliasDefault = Duration(minutes: 10);
  static Duration get autocreateAliasDefault => _autocreateAliasDefault;
  static Duration _autoCreateAlias = _autocreateAliasDefault;

  static Duration get autoCreateAlias => _autoCreateAlias;
  static set autoCreateAlias(Duration dur) {
    if (autoCreateAliasLimits.isValid(dur.inMinutes)) {
      _autoCreateAlias = dur;
    }
  }

  static AppSettingLimits autoCreateAliasLimits = AppSettingLimits(
      cacheKey: Cache.globalsAutocreateAlias,
      min: 10,
      zeroDisables: true,
      unit: SettingUnits.minute);

  static Future<void> loadSettings() async {
    try {
      statusStandingRequireAlias = await Cache.globalsStatusStandingRequireAlias
          .load<bool>(_statusStandingRequireAliasDefault);

      backgroundTrackingEnabled = await Cache.globalsBackgroundTrackingEnabled
          .load<bool>(_backgroundTrackingEnabledDefault);

      _backgroundLookupDuration = await Cache.globalsBackgroundLookupDuration
          .load<Duration>(_backgroundLookupDurationDefault);

      _cacheGpsTime =
          await Cache.globalsCacheGpsTime.load<Duration>(_cacheGpsTimeDefault);

      _distanceTreshold = await Cache.globalsDistanceTreshold
          .load<int>(_distanceTresholdDefault);

      _timeRangeTreshold = await Cache.globalsTimeRangeTreshold
          .load<Duration>(_timeRangeTresholdDefault);

      _trackPointInterval = await Cache.globalsTrackPointInterval
          .load<Duration>(_trackPointIntervalDefault);

      _gpsPointsSmoothCount = await Cache.globalsGpsPointsSmoothCount
          .load<int>(_gpsPointsSmoothCountDefault);

      osmLookupCondition = await Cache.globalsOsmLookupCondition
          .load<OsmLookupConditions>(_osmLookupConditionDefault);

      /// processed value
      _autoCreateAlias = await Cache.globalsAutocreateAlias
          .load<Duration>(_autocreateAliasDefault);

      publishToCalendar = await Cache.globalPublishToCalendar
          .load<bool>(_publishToCalendarDefault);
    } catch (e, stk) {
      logger.error('load settings: $e', stk);
    }
  }

  static Future<void> reset() async {
    weekDays = _weekDaysDefault;
    backgroundTrackingEnabled = _backgroundTrackingEnabledDefault;
    statusStandingRequireAlias = _statusStandingRequireAliasDefault;
    _backgroundLookupDuration = _backgroundLookupDurationDefault;
    _cacheGpsTime = _cacheGpsTimeDefault;
    _distanceTreshold = _distanceTresholdDefault;
    _timeRangeTreshold = _timeRangeTresholdDefault;
    _trackPointInterval = _trackPointIntervalDefault;
    _gpsPointsSmoothCount = _gpsPointsSmoothCountDefault;
    osmLookupCondition = _osmLookupConditionDefault;
    _autoCreateAlias = _autocreateAliasDefault;
    publishToCalendar = _publishToCalendarDefault;
    await saveSettings();
  }

  static Future<bool> updateValue(
      {required Cache key, required dynamic value}) async {
    if (value.runtimeType == int) {
      switch (key) {
        case Cache.globalsBackgroundLookupDuration:
          backgroundLookupDuration =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.globalsCacheGpsTime:
          cacheGpsTime =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.globalsDistanceTreshold:
          distanceTreshold = await key.save<int>(value as int);
          break;

        case Cache.globalsTimeRangeTreshold:
          timeRangeTreshold =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.globalsTrackPointInterval:
          trackPointInterval =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.globalsGpsPointsSmoothCount:
          gpsPointsSmoothCount = await key.save<int>(value as int);
          break;

        case Cache.globalsAutocreateAlias:
          autoCreateAlias =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        default:
          logger.error('unsupportet key $key for type ${key.cacheType}',
              StackTrace.current);
          return false;
      }
    }
    if (key.cacheType == bool && value.runtimeType == key.cacheType) {
      switch (key) {
        case Cache.globalsStatusStandingRequireAlias:
          statusStandingRequireAlias = await key.save<bool>(value as bool);
          return true;

        case Cache.globalsBackgroundTrackingEnabled:
          backgroundTrackingEnabled = await key.save<bool>(value as bool);
          return true;

        case Cache.globalPublishToCalendar:
          publishToCalendar = await key.save<bool>(value as bool);
          return true;

        default:
          logger.error('unsupportet key $key for type ${key.cacheType}',
              StackTrace.current);
          return false;
      }
    }
    if (key.cacheType == OsmLookupConditions &&
        value.runtimeType == key.cacheType) {
      osmLookupCondition =
          await key.save<OsmLookupConditions>(value as OsmLookupConditions);
      return true;
    }
    return false;
  }

  static Future<void> saveSettings() async {
    await Cache.globalsBackgroundTrackingEnabled
        .save<bool>(backgroundTrackingEnabled);

    await Cache.globalsStatusStandingRequireAlias
        .save<bool>(statusStandingRequireAlias);

    await Cache.globalsBackgroundLookupDuration
        .save<Duration>(backgroundLookupDuration);

    await Cache.globalsCacheGpsTime.save<Duration>(cacheGpsTime);

    await Cache.globalsDistanceTreshold.save<int>(distanceTreshold);

    await Cache.globalsTimeRangeTreshold.save<Duration>(timeRangeTreshold);

    await Cache.globalsTrackPointInterval.save<Duration>(trackPointInterval);

    await Cache.globalsGpsPointsSmoothCount.save<int>(gpsPointsSmoothCount);

    await Cache.globalsOsmLookupCondition
        .save<OsmLookupConditions>(osmLookupCondition);

    await Cache.globalsAutocreateAlias.save<Duration>(autoCreateAlias);

    await Cache.globalPublishToCalendar.save<bool>(publishToCalendar);
  }
}
