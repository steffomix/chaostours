import "package:chaostours/cache.dart";
import 'package:chaostours/conf/app_settings.dart';
import 'dart:math' as math;
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/alias/widget_edit_alias_osm.dart';

enum Unit {
  piece(1),
  minute(60),
  second(1),
  meter(1),
  km(1000);

  final int multiplicator;
  const Unit(this.multiplicator);
}

class Option {
  static final Logger logger = Logger.logger<Option>();
  Cache cache;
  dynamic defaultValue;
  int? minValue;
  int? maxValue;
  bool? zeroDeactivates;
  Unit unit = Unit.piece;

  int pruneInt(String data) {
    int value = int.tryParse(data) ?? (defaultValue as int);
    if (minValue != null) {
      value = math.max(minValue!, value);
    }
    if (maxValue != null) {
      value = math.min(maxValue!, value);
    }
    return value * unit.multiplicator;
  }

  Future<void> save(String data) async {
    switch (cache.cacheType) {
      case String:
        await cache.save<String>(data.trim());
        break;

      case int:
        int value = pruneInt(data);
        await cache.save<int>(value);
        break;

      case Duration:
        int value = pruneInt(data);
        await cache.save<Duration>(Duration(seconds: value));
        break;

      case OsmLookupConditions:
        var value = OsmLookupConditions.byName(data) ??
            (defaultValue as OsmLookupConditions);
        await cache.save<OsmLookupConditions>(value);
        break;

      default:
        logger.warn(
            'processUserInput ${cache.name}: Type ${data.runtimeType} not implemented');
    }
  }

  Option._option(this.cache,
      {required this.defaultValue,
      this.minValue,
      this.maxValue,
      this.unit = Unit.piece,
      this.zeroDeactivates});

  factory Option(Cache cache) {
    switch (cache) {
      case Cache.appSettingAutocreateAlias:
        return Option._option(cache, defaultValue: true);

      case Cache.appSettingBackgroundLookupDuration:
        return Option._option(cache,
            defaultValue: 30, minValue: 15, unit: Unit.second);

      case Cache.appSettingBackgroundTrackingEnabled:
        return Option._option(cache, defaultValue: true);

      case Cache.appSettingCacheGpsTime:
        return Option._option(
          cache,
          defaultValue: const Duration(seconds: 10),
          minValue: 0,
          maxValue: 60 * 60,
          zeroDeactivates: true,
        );

      case Cache.appSettingDistanceTreshold:
        return Option._option(
          cache,
          defaultValue: 100,
          minValue: 20,
        );

      case Cache.appSettingGpsPointsSmoothCount:
        return Option._option(cache, defaultValue: 3);

      case Cache.appSettingOsmLookupCondition:
        return Option._option(cache,
            defaultValue: OsmLookupConditions.onCreateAlias);

      case Cache.appSettingPublishToCalendar:
        return Option._option(cache, defaultValue: true);

      default:
        throw 'Option for ${cache.name} not implemented';
    }
  }
}
