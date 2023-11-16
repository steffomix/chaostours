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
import 'package:chaostours/address.dart';
import 'package:chaostours/gps.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'dart:math' as math;
// import 'package:chaostours/logger.dart';

enum OsmLookupConditions {
  never,
  onUserRequest,
  onUserCreateAlias,
  onAutoCreateAlias,
  onStatusChanged,
  onBackgroundGps,
  always;

  static OsmLookupConditions? byName(String name) {
    for (var value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static Future<bool> allowLookup(OsmLookupConditions condition) async {
    OsmLookupConditions setting = await Cache.appSettingOsmLookupCondition
        .load<OsmLookupConditions>(OsmLookupConditions.never);
    return setting.index > 0 && condition.index <= setting.index;
  }

  static Future<String> saveBackgroundAddress(
      {required GPS gps, required OsmLookupConditions condition}) async {
    if (await OsmLookupConditions.allowLookup(condition)) {
      String address = (await Address(gps).lookupAddress()).toString();
      return await Cache.backgroundAddress.save<String>(address);
    }
    return 'Address lookup permission denied on condition.${condition.name}';
  }

  static Future<String?> lookupAddress(
      {required GPS gps, required OsmLookupConditions condition}) async {
    if (await OsmLookupConditions.allowLookup(condition)) {
      return (await Address(gps).lookupAddress()).toString();
    }
    return null;
  }
}

enum Weekdays {
  mondayFirst(['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']),
  sundayFirst(['', 'So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa']);

  final List<String> weekdays;

  const Weekdays(this.weekdays);
}

enum Unit {
  piece(1),
  minute(60),
  second(1),
  meter(1),
  km(1000),
  option(1);

  final int multiplicator;
  const Unit(this.multiplicator);
}

class AppUserSettings {
  static final Logger logger = Logger.logger<AppUserSettings>();

  static final Map<Cache, AppUserSettings> _appUserSettings = {};
  Cache cache;
  dynamic _cachedValue;
  dynamic defaultValue;
  int? minValue;
  int? maxValue;
  bool? zeroDeactivates;
  Unit unit = Unit.piece;
  Future<void> Function() resetToDefault;
  Future<int> Function(int value)? extraCheck;
  Widget title;
  Widget description;

  AppUserSettings._option(this.cache,
      {required this.title,
      required this.description,
      required this.defaultValue,
      required this.resetToDefault,
      this.extraCheck,
      this.minValue,
      this.maxValue,
      required this.unit,
      this.zeroDeactivates});

  factory AppUserSettings(Cache cache) {
    switch (cache) {
      case Cache.appSettingTimeRangeTreshold:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.minute,
          minValue: 60, // 1 minute
          maxValue: 60 * 60, // 10 hours
          defaultValue: const Duration(minutes: 3),
          resetToDefault: () async {
            await cache.save<Duration>(
                AppUserSettings(cache).defaultValue as Duration);
          },
          extraCheck: (int value) async {
            // recheck autocreate alias duration
            int minCreate = value * 2;
            Cache cAutoCreate = Cache.appSettingAutocreateAlias;
            int autoCreate = (await cAutoCreate.load<Duration>(
                    AppUserSettings(cAutoCreate).defaultValue as Duration))
                .inSeconds;
            if (autoCreate < minCreate) {
              await cAutoCreate.save<Duration>(Duration(seconds: minCreate));
            }
            // recheck smoothCount
            Cache cSmooth = Cache.appSettingGpsPointsSmoothCount;
            int smooth = await cSmooth
                .load<int>(AppUserSettings(cSmooth).defaultValue as int);
            if (smooth > 0) {
              Cache cLookup = Cache.appSettingBackgroundTrackingInterval;
              int lookup = (await cLookup.load<Duration>(
                      AppUserSettings(cLookup).defaultValue as Duration))
                  .inSeconds;
              int maxSmooth = maxSmoothCount(value, lookup);
              if (smooth > maxSmooth) {
                await cSmooth.save<int>(maxSmooth);
              }
            }

            return value;
          },
        );

      case Cache.appSettingAutocreateAlias:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.minute,
          minValue: 60 * 5, // 5 minutes
          defaultValue: Duration(seconds: 60 * 15),
          resetToDefault: () async {
            await cache.save<Duration>(
                AppUserSettings(cache).defaultValue as Duration);
          }, //
          extraCheck: (int value) async {
            /// must be at least appSettingTimeRangeTreshold * 2
            Cache cTimeRange = Cache.appSettingTimeRangeTreshold;
            int timeRange = (await cTimeRange.load<Duration>(
                    AppUserSettings(cTimeRange).defaultValue as Duration))
                .inSeconds;
            int min = timeRange * 2;
            if (value < min) {
              return min;
            }
            return value;
          }, //
        ); // 15 minutes

      case Cache.appSettingBackgroundTrackingInterval:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache, //
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.second,
          minValue: 15,
          defaultValue: Duration(seconds: 30),
          resetToDefault: () async {
            await cache.save<Duration>(
                AppUserSettings(cache).defaultValue as Duration);
          }, //
          extraCheck: (int value) async {
            /// timeRange must at least allow 4 lookups
            int minTimeRange = value * 4;
            Cache cTimeRange = Cache.appSettingTimeRangeTreshold;
            int timeRange = (await cTimeRange.load<Duration>(
                    AppUserSettings(cTimeRange).defaultValue as Duration))
                .inSeconds;
            if (minTimeRange > timeRange) {
              // modify timeRange
              await cTimeRange.save<Duration>(Duration(seconds: minTimeRange));
              // recheck autocreate alias duration
              int minCreate = minTimeRange * 2;
              Cache cAutoCreate = Cache.appSettingAutocreateAlias;
              int autoCreate = (await cAutoCreate.load<Duration>(
                      AppUserSettings(cAutoCreate).defaultValue as Duration))
                  .inSeconds;
              if (autoCreate < minCreate) {
                await cAutoCreate.save<Duration>(Duration(seconds: minCreate));
              }
            }

            // recheck smoothCount
            Cache cSmooth = Cache.appSettingGpsPointsSmoothCount;
            int smooth = await cSmooth
                .load<int>(AppUserSettings(cSmooth).defaultValue as int);
            if (smooth > 0) {
              int maxSmooth = maxSmoothCount(timeRange, value);
              if (smooth > maxSmooth) {
                await cSmooth.save<int>(maxSmooth);
              }
            }
            return value;
          },
        );

      case Cache.appSettingGpsPointsSmoothCount:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.piece,
          defaultValue: 3,
          resetToDefault: () async {
            await cache.save<int>(AppUserSettings(cache).defaultValue as int);
          },
          extraCheck: (int value) async {
            Cache cTimeRange = Cache.appSettingTimeRangeTreshold;
            int timeRange = (await cTimeRange.load<Duration>(
                    AppUserSettings(cTimeRange).defaultValue as Duration))
                .inSeconds;
            Cache cLookup = Cache.appSettingBackgroundTrackingInterval;
            int lookup = (await cLookup.load<Duration>(
                    AppUserSettings(cLookup).defaultValue as Duration))
                .inSeconds;
            int maxCount = (timeRange / lookup).floor() - 1;
            if (value > maxCount) {
              return maxCount;
            }
            return value;
          },
        );

      case Cache.appSettingBackgroundTrackingEnabled:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.option,
          defaultValue: true,
          resetToDefault: () async {
            await cache.save<bool>(AppUserSettings(cache).defaultValue as bool);
          },
        );

      case Cache.appSettingCacheGpsTime:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.second,
          defaultValue: const Duration(seconds: 10),
          resetToDefault: () async {
            await cache.save<Duration>(
                AppUserSettings(cache).defaultValue as Duration);
          },
          minValue: 0,
          maxValue: 60, // 1 minute
          zeroDeactivates: true,
        );

      case Cache.appSettingDistanceTreshold:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.meter,
          defaultValue: 100,
          resetToDefault: () async {
            await cache.save<int>(AppUserSettings(cache).defaultValue as int);
          },
          minValue: 20,
        );

      case Cache.appSettingOsmLookupCondition:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.option,
          defaultValue: OsmLookupConditions.onAutoCreateAlias,
          resetToDefault: () async {
            await cache.save<OsmLookupConditions>(
                AppUserSettings(cache).defaultValue as OsmLookupConditions);
          },
        );

      case Cache.appSettingWeekdays:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.option,
          defaultValue: Weekdays.mondayFirst,
          resetToDefault: () async {
            await cache.save<Weekdays>(
                AppUserSettings(cache).defaultValue as Weekdays);
          },
        );

      case Cache.appSettingPublishToCalendar:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.option,
          defaultValue: true,
          resetToDefault: () async {
            await cache.save<bool>(AppUserSettings(cache).defaultValue as bool);
          },
        );

      case Cache.appSettingStatusStandingRequireAlias:
        return _appUserSettings[cache] ??= AppUserSettings._option(
          cache,
          title: Text(cache.toString()),
          description: Text('Description of ${cache.toString()}'),
          unit: Unit.option,
          defaultValue: true,
          resetToDefault: () async {
            await cache.save<bool>(AppUserSettings(cache).defaultValue as bool);
          },
        );

      case Cache.appSettingForegroundUpdateInterval:
        return _appUserSettings[cache] ??= AppUserSettings._option(cache,
            title: Text(cache.toString()),
            description: Text('Description of ${cache.toString()}'),
            unit: Unit.second,
            minValue: 1,
            maxValue: 30,
            defaultValue: Duration(seconds: 3), //
            resetToDefault: () async {
          await cache
              .save<Duration>(AppUserSettings(cache).defaultValue as Duration);
        });

      case Cache.appSettingTimeZone:
        return _appUserSettings[cache] ??= AppUserSettings._option(cache,
            title: Text(cache.toString()),
            description: Text('Description of ${cache.toString()}'),
            unit: Unit.piece,
            defaultValue: 'Europe/Berlin', //
            resetToDefault: () async {
          await cache
              .save<String>(AppUserSettings(cache).defaultValue as String);
        });

      default:
        throw 'AppUserSettings for ${cache.name} not implemented';
    }
  }

  static int maxSmoothCount(int timeRange, int lookup) {
    return (timeRange / lookup).floor() - 1;
  }

  Future<int> pruneInt(String? data) async {
    int value = (int.tryParse(data ?? '') ?? (defaultValue as int)) *
        unit.multiplicator;
    if (minValue != null) {
      value = math.max(minValue!, value);
    }
    if (maxValue != null) {
      value = math.min(maxValue!, value);
    }
    value = (await extraCheck?.call(value)) ?? value;
    return value;
  }

  Future<void> save(String data) async {
    switch (cache.cacheType) {
      case String:
        String value = data.trim();
        await cache.save<String>(value);
        break;

      case int:
        int value = await pruneInt(data);
        await cache.save<int>(value);
        break;

      case bool:
        bool value = (data == '1' || data == 'true') ? true : false;
        await cache.save<bool>(value);
        break;

      case Duration:
        int value = await pruneInt(data);
        await cache.save<Duration>(Duration(seconds: value));
        break;

      case OsmLookupConditions:
        var value = OsmLookupConditions.byName(data) ??
            (defaultValue as OsmLookupConditions);
        await cache.save<OsmLookupConditions>(value);
        break;

      default:
        logger.warn(
            'save ${cache.name}: Type ${data.runtimeType} not implemented');
    }
  }

  Future<String> load() async {
    switch (cache.cacheType) {
      case String:
        return (_cachedValue ??= await cache.load<String>(defaultValue))
            as String;

      case int:
        int value = await cache.load<int>(defaultValue as int);
        return (value / unit.multiplicator).round().toString();

      case bool:
        bool value = await cache.load<bool>(defaultValue as bool);
        return value ? '1' : '0';

      case Duration:
        Duration value = await cache.load<Duration>(defaultValue as Duration);
        return (value.inSeconds / unit.multiplicator).round().toString();

      case OsmLookupConditions:
        OsmLookupConditions value = await cache
            .load<OsmLookupConditions>(defaultValue as OsmLookupConditions);
        return value.name;

      default:
        logger.warn('load: ${cache.cacheType} not implemented');
    }
    return '${cache.cacheType} Not implemented!';
  }
}







///
///
///
///
///
///
///
///
///
///
///
///
///
///








/*
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

class AppUserSettings {
  static final Logger logger = Logger.logger<AppUserSettings>();

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
  /// All setting names must match enum AppUserSettings values in app_settings.dart
  /// if backgroundTracking is enabled and starts automatic
  static const bool backgroundTrackingEnabledDefault = true;
  static bool backgroundTrackingEnabled = backgroundTrackingEnabledDefault;

  ///
  /// If true, status standing is triggered only if location has an alias.
  static const bool statusStandingRequireAliasDefault = true;
  static bool statusStandingRequireAlias = statusStandingRequireAliasDefault;

  /// currently only used on live tracking page.
  /// Looks for new background data.
  static const Duration backgroundLookupDurationDefault = Duration(seconds: 15);
  static Duration _backgroundLookupDuration = backgroundLookupDurationDefault;
  static Duration get backgroundLookupDuration => _backgroundLookupDuration;
  static AppSettingLimits backgroundLookupDurationLimits = AppSettingLimits(
      cacheKey: Cache.appSettingBackgroundLookupDuration, min: 5, max: 60);
  static set backgroundLookupDuration(Duration value) {
    if (backgroundLookupDurationLimits.isValid(value.inSeconds)) {
      _backgroundLookupDuration = value;
    }
  }

  /// User interactions can cause massive foreground gps lookups.
  /// to prevent application lags, gps is chached for some seconds
  static const Duration cacheGpsTimeDefault = Duration(seconds: 10);
  static Duration _cacheGpsTime = cacheGpsTimeDefault;
  static Duration get cacheGpsTime => _cacheGpsTime;
  static AppSettingLimits cachGpsTimeLimits = AppSettingLimits(
      cacheKey: Cache.appSettingCacheGpsTime, max: 600, zeroDisables: true);

  static set cacheGpsTime(Duration value) {
    if (cachGpsTimeLimits.isValid(value.inSeconds)) {
      _cacheGpsTime = value;
    }
  }

  /// the distance to travel within <timeRangeTreshold> to trigger a status change.
  /// Above to trigger moving, below to trigger standing
  /// This is also the default radius for new alias
  static const int distanceTresholdDefault = 100; //meters
  static int _distanceTreshold = distanceTresholdDefault;
  static int get distanceTreshold => _distanceTreshold;
  static AppSettingLimits distanceTresholdLimits = AppSettingLimits(
      cacheKey: Cache.appSettingDistanceTreshold,
      min: 10,
      unit: SettingUnits.meter);
  static set distanceTreshold(int value) {
    if (distanceTresholdLimits.isValid(value)) {
      _distanceTreshold = value;
    }
  }

  /// stop time needed to trigger stop.
  /// Shoud be at least 3 times more than trackPointDuration
  static const Duration timeRangeTresholdDefault = Duration(seconds: 180);
  static Duration _timeRangeTreshold = timeRangeTresholdDefault;
  static Duration get timeRangeTreshold => _timeRangeTreshold;
  static set timeRangeTreshold(Duration value) {
    if (timeRangeTresholdLimits.isValid(value.inSeconds) &&
        value.inSeconds >= trackPointInterval.inSeconds * 3) {
      _timeRangeTreshold = value;
    }
  }

  static AppSettingLimits timeRangeTresholdLimits = AppSettingLimits(
      cacheKey: Cache.appSettingTimeRangeTreshold,
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
        cacheKey: Cache.appSettingTrackPointInterval,
        min: 15,
        max: (_timeRangeTreshold.inSeconds / 1).ceil());
  }

  /// compensate unprecise gps by using average of given gpsPoints.
  /// That means that a smooth count of 3 requires at least 4 gpsPoints
  /// for trackpoint calculation
  static const int gpsPointsSmoothCountDefault = 5;
  static int _gpsPointsSmoothCount = gpsPointsSmoothCountDefault;
  static int get gpsPointsSmoothCount => _gpsPointsSmoothCount;
  static set gpsPointsSmoothCount(int count) {
    if (gpsPointsSmoothCountLimits.isValid(count)) {
      _gpsPointsSmoothCount = count;
    }
  }

  static AppSettingLimits get gpsPointsSmoothCountLimits {
    return AppSettingLimits(
        cacheKey: Cache.appSettingGpsPointsSmoothCount,
        min: 2,
        max: (timeRangeTreshold.inSeconds / trackPointInterval.inSeconds)
            .floor(),
        zeroDisables: true,
        unit: SettingUnits.piece);
  }

  static const bool publishToCalendarDefault = true;
  static bool publishToCalendar = publishToCalendarDefault;

  /// when background looks for an address of given gps
  static const OsmLookupConditions osmLookupConditionDefault =
      OsmLookupConditions.onStatusChanged;
  static OsmLookupConditions osmLookupCondition = osmLookupConditionDefault;

  /// if no alias is found on trackingstatus standing
  /// how long in minutes to wait until an alias is autocreated
  /// 0 = disabled
  static const Duration autocreateAliasDefault = Duration(minutes: 10);
  static Duration get autoCreateAliasDefault => autocreateAliasDefault;
  static Duration _autoCreateAlias = autocreateAliasDefault;

  static Duration get autoCreateAlias => _autoCreateAlias;
  static set autoCreateAlias(Duration dur) {
    if (autoCreateAliasLimits.isValid(dur.inMinutes)) {
      _autoCreateAlias = dur;
    }
  }

  static AppSettingLimits autoCreateAliasLimits = AppSettingLimits(
      cacheKey: Cache.appSettingAutocreateAlias,
      min: 10,
      zeroDisables: true,
      unit: SettingUnits.minute);

  static Future<void> loadSettings() async {
    try {
      statusStandingRequireAlias = await Cache
          .appSettingStatusStandingRequireAlias
          .load<bool>(statusStandingRequireAliasDefault);

      backgroundTrackingEnabled = await Cache
          .appSettingBackgroundTrackingEnabled
          .load<bool>(backgroundTrackingEnabledDefault);

      _backgroundLookupDuration = await Cache.appSettingBackgroundLookupDuration
          .load<Duration>(backgroundLookupDurationDefault);

      _cacheGpsTime = await Cache.appSettingCacheGpsTime
          .load<Duration>(cacheGpsTimeDefault);

      _distanceTreshold = await Cache.appSettingDistanceTreshold
          .load<int>(distanceTresholdDefault);

      _timeRangeTreshold = await Cache.appSettingTimeRangeTreshold
          .load<Duration>(timeRangeTresholdDefault);

      _trackPointInterval = await Cache.appSettingTrackPointInterval
          .load<Duration>(_trackPointIntervalDefault);

      _gpsPointsSmoothCount = await Cache.appSettingGpsPointsSmoothCount
          .load<int>(gpsPointsSmoothCountDefault);

      osmLookupCondition = await Cache.appSettingOsmLookupCondition
          .load<OsmLookupConditions>(osmLookupConditionDefault);

      /// processed value
      _autoCreateAlias = await Cache.appSettingAutocreateAlias
          .load<Duration>(autocreateAliasDefault);

      publishToCalendar = await Cache.appSettingPublishToCalendar
          .load<bool>(publishToCalendarDefault);
    } catch (e, stk) {
      logger.error('load settings: $e', stk);
    }
  }

  static Future<void> reset() async {
    weekDays = _weekDaysDefault;
    backgroundTrackingEnabled = backgroundTrackingEnabledDefault;
    statusStandingRequireAlias = statusStandingRequireAliasDefault;
    _backgroundLookupDuration = backgroundLookupDurationDefault;
    _cacheGpsTime = cacheGpsTimeDefault;
    _distanceTreshold = distanceTresholdDefault;
    _timeRangeTreshold = timeRangeTresholdDefault;
    _trackPointInterval = _trackPointIntervalDefault;
    _gpsPointsSmoothCount = gpsPointsSmoothCountDefault;
    osmLookupCondition = osmLookupConditionDefault;
    _autoCreateAlias = autocreateAliasDefault;
    publishToCalendar = publishToCalendarDefault;
    await saveSettings();
  }

  static Future<bool> updateValue(
      {required Cache key, required dynamic value}) async {
    if (value.runtimeType == int) {
      switch (key) {
        case Cache.appSettingBackgroundLookupDuration:
          backgroundLookupDuration =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.appSettingCacheGpsTime:
          cacheGpsTime =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.appSettingDistanceTreshold:
          distanceTreshold = await key.save<int>(value as int);
          break;

        case Cache.appSettingTimeRangeTreshold:
          timeRangeTreshold =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.appSettingTrackPointInterval:
          trackPointInterval =
              await key.save<Duration>(Duration(seconds: value as int));
          break;

        case Cache.appSettingGpsPointsSmoothCount:
          gpsPointsSmoothCount = await key.save<int>(value as int);
          break;

        case Cache.appSettingAutocreateAlias:
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
        case Cache.appSettingStatusStandingRequireAlias:
          statusStandingRequireAlias = await key.save<bool>(value as bool);
          return true;

        case Cache.appSettingBackgroundTrackingEnabled:
          backgroundTrackingEnabled = await key.save<bool>(value as bool);
          return true;

        case Cache.appSettingPublishToCalendar:
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
    await Cache.appSettingBackgroundTrackingEnabled
        .save<bool>(backgroundTrackingEnabled);

    await Cache.appSettingStatusStandingRequireAlias
        .save<bool>(statusStandingRequireAlias);

    await Cache.appSettingBackgroundLookupDuration
        .save<Duration>(backgroundLookupDuration);

    await Cache.appSettingCacheGpsTime.save<Duration>(cacheGpsTime);

    await Cache.appSettingDistanceTreshold.save<int>(distanceTreshold);

    await Cache.appSettingTimeRangeTreshold.save<Duration>(timeRangeTreshold);

    await Cache.appSettingTrackPointInterval.save<Duration>(trackPointInterval);

    await Cache.appSettingGpsPointsSmoothCount.save<int>(gpsPointsSmoothCount);

    await Cache.appSettingOsmLookupCondition
        .save<OsmLookupConditions>(osmLookupCondition);

    await Cache.appSettingAutocreateAlias.save<Duration>(autoCreateAlias);

    await Cache.appSettingPublishToCalendar.save<bool>(publishToCalendar);
  }
}
*/