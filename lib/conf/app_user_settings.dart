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

import 'package:chaostours/address.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/database/cache.dart';
import 'dart:math' as math;
// import 'package:chaostours/logger.dart';

abstract class EnumUserSetting<T> {
  final Widget title;
  final int index = 0;
  const EnumUserSetting(this.title);
}

enum OsmLookupConditions implements EnumUserSetting<OsmLookupConditions> {
  never(Text('Never, completely restricted')),
  onUserRequest(Text('On user requests')),
  onUserCreateAlias(Text('On user create alias')),
  onAutoCreateAlias(Text('On auto create alias')),
  onStatusChanged(Text('On tracking status changed')),
  onBackgroundGps(Text('On every background GPS interval')),
  always(Text('Always, no restrictions'));

  static Map<OsmLookupConditions, Address> address = {};
  @override
  final Widget title;
  const OsmLookupConditions(this.title);

  static OsmLookupConditions? byName(String name) {
    for (var value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  Future<bool> allowLookup() async {
    OsmLookupConditions setting = await Cache.appSettingOsmLookupCondition
        .load<OsmLookupConditions>(OsmLookupConditions.never);
    bool licenseConsent = await Cache.licenseConsentOsm.load<bool>(false);
    return licenseConsent && setting.index > 0 && index <= setting.index;
  }
}

enum Weekdays implements EnumUserSetting<OsmLookupConditions> {
  mondayFirst(['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'], Text('Monday')),
  sundayFirst(['', 'So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'], Text('Sunday'));

  final List<String> weekdays;
  @override
  final Widget title;

  const Weekdays(this.weekdays, this.title);
}

enum DateFormat implements EnumUserSetting<OsmLookupConditions> {
  yyyymmdd(Text('YYYY:MM:DD')),
  ddmmyyyy(Text('DD:MM:YYYY'));

  @override
  final Widget title;

  const DateFormat(this.title);
}

enum GpsPrecision implements EnumUserSetting<OsmLookupConditions> {
  best(Text('Best')),
  coarse(Text('Coarse')),
  ;

  @override
  final Widget title;
  const GpsPrecision(this.title);
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

class AppUserSetting {
  static final Logger logger = Logger.logger<AppUserSetting>();

  static final Map<Cache, AppUserSetting> _appUserSettings = {};
  Cache cache;
  dynamic _cachedValue;
  dynamic defaultValue;
  int? minValue;
  int? maxValue;
  bool? zeroDeactivates;
  Unit unit = Unit.piece;
  Future<void> Function() resetToDefault;
  Future<int> Function(int value)? extraCheck;
  Widget? title;
  Widget? description;

  AppUserSetting._option(this.cache,
      {required this.title,
      required this.description,
      required this.defaultValue,
      required this.resetToDefault,
      this.extraCheck,
      this.minValue,
      this.maxValue,
      required this.unit,
      this.zeroDeactivates});

  static Future<void> resetAllToDefault() async {
    for (var setting in [
      Cache.appSettingTimeRangeTreshold,
      Cache.appSettingAutocreateAliasDuration,
      Cache.appSettingBackgroundTrackingInterval,
      Cache.appSettingGpsPointsSmoothCount,
      Cache.appSettingBackgroundTrackingEnabled,
      Cache.appSettingCacheGpsTime,
      Cache.appSettingDistanceTreshold,
      Cache.appSettingOsmLookupCondition,
      Cache.appSettingWeekdays,
      Cache.appSettingPublishToCalendar,
      Cache.appSettingAutocreateAlias,
      Cache.appSettingStatusStandingRequireAlias,
      Cache.appSettingForegroundUpdateInterval,
      Cache.appSettingTimeZone
    ]) {
      await AppUserSetting(setting).resetToDefault();
    }
  }

  factory AppUserSetting(Cache cache) {
    switch (cache) {
      ///
      /// Tracking Values
      ///

      case Cache.appSettingBackgroundTrackingInterval:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache, //
          title: const Text('Background GPS tracking interval duration.'),
          description: const Text('A higher value consumes less battery, '
              'but it also takes longer to measure the status of stopping or moving.\n'
              'NOTE:\n'
              'The tracking execution time can take some seconds and will be added.'),
          unit: Unit.second,
          minValue: 3,
          defaultValue: const Duration(seconds: 30),
          resetToDefault: () async {
            await cache
                .save<Duration>(AppUserSetting(cache).defaultValue as Duration);
          }, //
          extraCheck: (int value) async {
            /// timeRange must at least allow 4 lookups
            int minTimeRange = value * 4;
            Cache cTimeRange = Cache.appSettingTimeRangeTreshold;
            int timeRange = (await cTimeRange.load<Duration>(
                    AppUserSetting(cTimeRange).defaultValue as Duration))
                .inSeconds;
            if (minTimeRange > timeRange) {
              // modify timeRange
              await cTimeRange.save<Duration>(Duration(seconds: minTimeRange));
            }

            // recheck autocreate alias duration
            int minCreate = minTimeRange * 2;
            Cache cAutoCreate = Cache.appSettingAutocreateAliasDuration;
            int autoCreate = (await cAutoCreate.load<Duration>(
                    AppUserSetting(cAutoCreate).defaultValue as Duration))
                .inSeconds;
            if (autoCreate < minCreate) {
              await cAutoCreate.save<Duration>(Duration(seconds: minCreate));
            }

            // recheck smoothCount
            Cache cSmooth = Cache.appSettingGpsPointsSmoothCount;
            int smooth = await cSmooth
                .load<int>(AppUserSetting(cSmooth).defaultValue as int);
            if (smooth > 0) {
              int maxSmooth = maxSmoothCount(timeRange, value);
              if (smooth > maxSmooth) {
                await cSmooth.save<int>(maxSmooth);
              }
            }
            return value;
          },
        );

      case Cache.appSettingTimeRangeTreshold:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Tracking status calculation time period'),
          description: const Text(
              'The time period in which the Moving or Stopping status is calculated.\n'
              'The System requires at least 3x time as the above "Background GPS Tracking Interval Duration" '
              'and will increase false values if necessary.'),
          unit: Unit.minute,
          minValue: 60, // 1 minute
          maxValue: null,
          defaultValue: const Duration(minutes: 3),
          resetToDefault: () async {
            await cache
                .save<Duration>(AppUserSetting(cache).defaultValue as Duration);
          },
          extraCheck: (int timeRangeSeconds) async {
            //
            // must be min 3x appSettingBackgroundTrackingInterval
            Cache cache = Cache.appSettingBackgroundTrackingInterval;
            int trackingSeconds = (await cache.load<Duration>(
                    AppUserSetting(cache).defaultValue as Duration))
                .inSeconds;
            timeRangeSeconds = math.max(timeRangeSeconds, trackingSeconds * 3);
            //
            // recheck autocreate alias duration
            int minCreateSeconds = timeRangeSeconds * 2;
            cache = Cache.appSettingAutocreateAliasDuration;
            int createSeconds = (await cache.load<Duration>(
                    AppUserSetting(cache).defaultValue as Duration))
                .inSeconds;
            if (createSeconds < minCreateSeconds) {
              await cache.save<Duration>(Duration(seconds: minCreateSeconds));
            }
            //
            // recheck smoothCount
            cache = Cache.appSettingGpsPointsSmoothCount;
            int smoothCount = await cache
                .load<int>(AppUserSetting(cache).defaultValue as int);
            if (smoothCount > 1) {
              // if not disabled
              int maxSmooth = maxSmoothCount(timeRangeSeconds, trackingSeconds);
              if (smoothCount > maxSmooth) {
                await cache.save<int>(maxSmooth);
              }
            }

            return timeRangeSeconds;
          },
        );

      case Cache.appSettingAutocreateAliasDuration:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Auto create Alias time period.'),
          description: const Text(
              'The period after which an alias will be created automatically if none is found. '
              'The "Status Standing Requires Alias" option must be activated to make it work. '
              'The system requires at least 2x time as the above "Time Range Threshold" '
              'and will automatically increase false values if necessary.'),
          unit: Unit.minute,
          minValue: 60 * 5, // 5 minutes
          defaultValue: const Duration(seconds: 60 * 15),
          resetToDefault: () async {
            await cache
                .save<Duration>(AppUserSetting(cache).defaultValue as Duration);
          }, //
          extraCheck: (int value) async {
            /// must be at least appSettingTimeRangeTreshold * 2
            Cache cTimeRange = Cache.appSettingTimeRangeTreshold;
            int timeRange = (await cTimeRange.load<Duration>(
                    AppUserSetting(cTimeRange).defaultValue as Duration))
                .inSeconds;
            int min = timeRange * 2;
            if (value < min) {
              return min;
            }
            return value;
          }, //
        ); // 15 minutes

      case Cache.appSettingGpsPointsSmoothCount:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('GPS smoothing count'),
          description: const Text(
              'Compensates for inaccurate GPS by calculating the average of the given number of GPS points. '
              'The maximum possible number of smooth points is calculated with the '
              'ceiling of "(Time Range Treshold" / "Background GPS Tracking Interval Duration) -1"'
              'A value below 2 disables this future.'),
          unit: Unit.piece,
          defaultValue: 3,
          zeroDeactivates: true,
          resetToDefault: () async {
            await cache.save<int>(AppUserSetting(cache).defaultValue as int);
          },
          extraCheck: (int value) async {
            Cache cTimeRange = Cache.appSettingTimeRangeTreshold;
            int timeRange = (await cTimeRange.load<Duration>(
                    AppUserSetting(cTimeRange).defaultValue as Duration))
                .inSeconds;
            //
            Cache cLookup = Cache.appSettingBackgroundTrackingInterval;
            int lookup = (await cLookup.load<Duration>(
                    AppUserSetting(cLookup).defaultValue as Duration))
                .inSeconds;
            //
            int maxCount = (timeRange / lookup).floor() - 1;
            if (value > maxCount) {
              return maxCount;
            }
            return value;
          },
        );

      ///
      ///
      ///

      case Cache.appSettingBackgroundTrackingEnabled:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Activate background GPS tracking'),
          description: const Text(
              'Please note that the Android System *WILL* put the Background GPS Tracking Future'
              ' to sleep after a while of user inactivity even if all battery saving options are deactivated. '
              'So that it is strongly recommended to start the App for at least once at morning to minimize the risk '
              'the tracking future get stopped by the system.'),
          unit: Unit.option,
          defaultValue: true,
          resetToDefault: () async {
            await cache.save<bool>(AppUserSetting(cache).defaultValue as bool);
          },
        );

      case Cache.appSettingCacheGpsTime:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Cache foreground GPS duration'),
          description: const Text(
              'GPS Cache can speed up the foreground functions of the app. '
              'However, you may receive an outdated GPS measurement result.'),
          unit: Unit.second,
          defaultValue: const Duration(seconds: 10),
          resetToDefault: () async {
            await cache
                .save<Duration>(AppUserSetting(cache).defaultValue as Duration);
          },
          minValue: 0,
          maxValue: 60, // 1 minute
          zeroDeactivates: true,
        );

      case Cache.appSettingDistanceTreshold:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Movement measuring range.'),
          description: const Text('Only relevant if no alias is found. '
              'All measuring points must be within this radius to trigger the status Standing. '
              'Or the path of the GPS calculation points must be greater '
              'than this measuring range value to trigger the status Moving.'),
          unit: Unit.meter,
          defaultValue: 100,
          resetToDefault: () async {
            await cache.save<int>(AppUserSetting(cache).defaultValue as int);
          },
          minValue: 20,
        );

      case Cache.appSettingOsmLookupCondition:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('OpenStreetMap Address Lookup Conditions'),
          description: const Text(
              'The requirements for when the app is allowed to search for an address. '
              'Higher restrictions reduce the app\'s data consumption.'),
          unit: Unit.option,
          defaultValue: OsmLookupConditions.onAutoCreateAlias,
          resetToDefault: () async {
            await cache.save<OsmLookupConditions>(
                AppUserSetting(cache).defaultValue as OsmLookupConditions);
          },
        );

      case Cache.appSettingDateFormat:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Date Format'),
          description: const Text('How Dates are displayed.'),
          unit: Unit.option,
          defaultValue: DateFormat.yyyymmdd,
          resetToDefault: () async {
            await cache.save<DateFormat>(
                AppUserSetting(cache).defaultValue as DateFormat);
          },
        );

      case Cache.appSettingWeekdays:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('First Weekday'),
          description: null,
          unit: Unit.option,
          defaultValue: Weekdays.mondayFirst,
          resetToDefault: () async {
            await cache
                .save<Weekdays>(AppUserSetting(cache).defaultValue as Weekdays);
          },
        );

      case Cache.appSettingPublishToCalendar:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Use Calender'),
          description: const Text('General publish to Calendar switch.'),
          unit: Unit.option,
          defaultValue: true,
          resetToDefault: () async {
            await cache.save<bool>(AppUserSetting(cache).defaultValue as bool);
          },
        );

      case Cache.appSettingAutocreateAlias:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Auto create Location Alias.'),
          description: const Text(
              'The App can create a Location Alias for you automatically after a certain time of standing. '
              ' It also can lookup an Address from OpenStreetMap.com for free, just make sure you have set the lookup permissions below.'),
          unit: Unit.option,
          defaultValue: true,
          resetToDefault: () async {
            await cache.save<bool>(AppUserSetting(cache).defaultValue as bool);
          },
        );

      case Cache.appSettingStatusStandingRequireAlias:
        return _appUserSettings[cache] ??= AppUserSetting._option(
          cache,
          title: const Text('Status stop required alias'),
          description: const Text(
              'If deactivated, the Movement measuring range is used as a virtual alias.'),
          unit: Unit.option,
          defaultValue: true,
          resetToDefault: () async {
            await cache.save<bool>(AppUserSetting(cache).defaultValue as bool);
          },
        );

      case Cache.appSettingForegroundUpdateInterval:
        return _appUserSettings[cache] ??= AppUserSetting._option(cache,
            title: const Text('Life tracking foreground lookup interval'),
            description: const Text(
                'The interval period in which the foreground process reloads the measurement data from the background process.'),
            unit: Unit.second,
            minValue: 3,
            maxValue: 30,
            defaultValue: const Duration(seconds: 5), //
            resetToDefault: () async {
          await cache
              .save<Duration>(AppUserSetting(cache).defaultValue as Duration);
        });

      case Cache.appSettingGpsPrecision:
        return _appUserSettings[cache] ??= AppUserSetting._option(cache,
            title: const Text('GPS precision'),
            description:
                const Text('Higher GPS precision consumes more battery power'),
            unit: Unit.piece,
            defaultValue: GpsPrecision.best, //
            resetToDefault: () async {
          await cache.save<GpsPrecision>(
              AppUserSetting(cache).defaultValue as GpsPrecision);
        });

      case Cache.appSettingTimeZone:
        return _appUserSettings[cache] ??= AppUserSetting._option(cache,
            title: const Text('ToDo - implement timezones'),
            description: Text('Description of ${cache.toString()}'),
            unit: Unit.piece,
            defaultValue: 'Europe/Berlin', //
            resetToDefault: () async {
          await cache
              .save<String>(AppUserSetting(cache).defaultValue as String);
        });

      default:
        throw 'AppUserSettings for ${cache.name} not implemented';
    }
  }

  static int maxSmoothCount(int timeRangeSeconds, int trackingSeconds) {
    return math.max((timeRangeSeconds / trackingSeconds).floor() - 1, 0);
  }

  Future<int> pruneInt(String? data) async {
    int value = (int.tryParse(data ?? '') ??
            (cache.cacheType == int
                ? defaultValue as int
                : ((defaultValue as Duration).inSeconds / unit.multiplicator)
                    .round())) *
        unit.multiplicator;

    if (minValue != null && value < minValue!) {
      value = math.max(minValue!, value);
    }
    if (maxValue != null && value > maxValue!) {
      value = math.min(maxValue!, value);
    }
    value = (await extraCheck?.call(value)) ?? value;
    return value;
  }

  Future<void> save(String? data) async {
    switch (cache.cacheType) {
      case const (String):
        String value = data?.trim() ?? defaultValue as String;
        await cache.save<String>(value);
        break;

      case const (int):
        int value = await pruneInt(data ?? defaultValue.toString());
        await cache.save<int>(value);
        break;

      case const (bool):
        bool value =
            (data != null && (data == '1' || data == 'true')) ? true : false;
        await cache.save<bool>(value);
        break;

      case const (Duration):
        int value = await pruneInt(data ??
            ((defaultValue as Duration).inSeconds / unit.multiplicator)
                .round()
                .toString());
        await cache.save<Duration>(Duration(seconds: value));
        break;

      case const (OsmLookupConditions):
        var value = OsmLookupConditions.byName(
                data ?? (defaultValue as OsmLookupConditions).name) ??
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
      case const (String):
        return (_cachedValue ??= await cache.load<String>(defaultValue))
            as String;

      case const (int):
        int value = await cache.load<int>(defaultValue as int);
        return (value / unit.multiplicator).round().toString();

      case const (bool):
        bool value = await cache.load<bool>(defaultValue as bool);
        return value ? '1' : '0';

      case const (Duration):
        Duration value = await cache.load<Duration>(defaultValue as Duration);
        return (value.inSeconds / unit.multiplicator).round().toString();

      case const (OsmLookupConditions):
        OsmLookupConditions value = await cache
            .load<OsmLookupConditions>(defaultValue as OsmLookupConditions);
        return value.name;

      case const (GpsPrecision):
        GpsPrecision value =
            await cache.load<GpsPrecision>(defaultValue as GpsPrecision);
        return value.name;

      default:
        logger.warn('load: ${cache.cacheType} not implemented');
    }
    return '${cache.cacheType} Not implemented!';
  }
}
