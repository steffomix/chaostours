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

import 'package:chaostours/database/cache_modules.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/value_expired.dart';
import 'package:geolocator/geolocator.dart';
/* 
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart'; 
*/

abstract class CacheModul {
  Future<void> setString(Cache key, String value);
  Future<void> setStringList(Cache key, List<String> value);
  Future<void> setInt(Cache key, int value);
  Future<void> setDouble(Cache key, double value);
  Future<void> setBool(Cache key, bool value);

  Future<String?> getString(Cache key);
  Future<List<String>?> getStringList(Cache key);
  Future<int?> getInt(Cache key);
  Future<double?> getDouble(Cache key);
  Future<bool?> getBool(Cache key);

  Future<void> remove(Cache key);
  Future<void> reload();
}

enum CacheModulId {
  database,
  sharedPreferences;
}

class StaticCache {
  static Weekdays _weekdays = Weekdays.mondayFirst;
  static Weekdays get weekdays => _weekdays;
  static DateFormat _dateFormat = DateFormat.yyyymmdd;
  static DateFormat get dateFormat => _dateFormat;

  static void update<T>(Cache cache, T value) {
    switch (cache) {
      case Cache.appSettingWeekdays:
        _weekdays = value as Weekdays;
        break;
      case Cache.appSettingDateFormat:
        _dateFormat = value as DateFormat;
        break;

      default:
      //
    }
  }
}

enum Cache {
  /// trigger off == TrackingStatus.none
  /// triggered by user, set to none in background
  trackingStatusTriggered(
      CacheModulId.sharedPreferences, TrackingStatus, expireAfterOneSecond),

  /// status change events
  backgroundGpsStartMoving(
      CacheModulId.sharedPreferences, GPS, expireAfterOneSecond),
  backgroundGpsStartStanding(
      CacheModulId.sharedPreferences, GPS, expireAfterOneSecond),
  backgroundGpsLastStatusChange(
      CacheModulId.sharedPreferences, GPS, expireAfterOneSecond),

  /// cache background to forground
  backgroundTrackingStatus(
      CacheModulId.sharedPreferences, TrackingStatus, expireAfterOneSecond),

  backgroundSharedAliasList(CacheModulId.sharedPreferences,
      List<SharedTrackpointAlias>, expireAfterOneSecond),
  backgroundSharedUserList(CacheModulId.sharedPreferences,
      List<SharedTrackpointUser>, expireAfterOneSecond),
  backgroundSharedTaskList(CacheModulId.sharedPreferences,
      List<SharedTrackpointTask>, expireAfterOneSecond),

  backgroundTrackPointUserNotes(
      CacheModulId.sharedPreferences, String, expireAfterOneSecond),

  /// tracking detection
  backgroundLastGps(CacheModulId.sharedPreferences, GPS, expireAfterOneSecond),
  backgroundGpsPoints(
      CacheModulId.sharedPreferences, List<GPS>, expireAfterOneSecond),
  backgroundGpsSmoothPoints(
      CacheModulId.sharedPreferences, List<GPS>, expireAfterOneSecond),
  backgroundGpsCalcPoints(
      CacheModulId.sharedPreferences, List<GPS>, expireAfterOneSecond),

  /// stores last lookup to prevent more than one osm lookups per second
  addressLastLookup(CacheModulId.sharedPreferences, int, expireAfterOneSecond),

  /// address updated on each background tick - if permission granted
  backgroundAddress(CacheModulId.sharedPreferences, String, expireImmediately),

  /// address updated on status change - if activated
  backgroundLastStandingAddress(
      CacheModulId.sharedPreferences, String, expireImmediately),

  /// eventCalendar
  backgroundCalendarLastEventIds(
      CacheModulId.sharedPreferences, List<CalendarEventId>, expireImmediately),

  /// startup consent
  licenseConsentChaosTours(CacheModulId.sharedPreferences, bool, expireNever),

  requestLicenseConsentOsm(CacheModulId.sharedPreferences, bool, expireNever),
  licenseConsentOsm(CacheModulId.sharedPreferences, bool, expireNever),
  requestOsmAddressLookup(CacheModulId.sharedPreferences, bool, expireNever),
  requestBatteryOptimization(CacheModulId.sharedPreferences, bool, expireNever),

  /// webSSLKey
  ///
  webSSLKey(CacheModulId.sharedPreferences, String, expireNever),

  /// appUserStettings
  appSettingBackgroundTrackingEnabled(CacheModulId.database, bool, expireNever),
  appSettingStatusStandingRequireAlias(
      CacheModulId.database, bool, expireNever),
  appSettingAutocreateAliasDuration(
      CacheModulId.database, Duration, expireNever),
  appSettingAutocreateAlias(CacheModulId.database, bool, expireNever),
  appSettingForegroundUpdateInterval(
      CacheModulId.database, Duration, expireNever),
  appSettingOsmLookupCondition(
      CacheModulId.database, OsmLookupConditions, expireNever),
  appSettingCacheGpsTime(CacheModulId.database, Duration, expireNever),
  appSettingLocationAccuracy(
      CacheModulId.database, LocationAccuracy, expireNever),
  appSettingDistanceTreshold(CacheModulId.database, int, expireNever),
  appSettingTimeRangeTreshold(CacheModulId.database, Duration, expireNever),
  appSettingBackgroundTrackingInterval(
      CacheModulId.database, Duration, expireNever),
  appSettingGpsPointsSmoothCount(CacheModulId.database, int, expireNever),
  appSettingPublishToCalendar(CacheModulId.database, bool, expireNever),
  appSettingTimeZone(CacheModulId.database, String, expireNever),
  appSettingWeekdays(CacheModulId.database, Weekdays, expireNever),
  appSettingDateFormat(CacheModulId.database, DateFormat, expireNever),
  appSettingGpsPrecision(CacheModulId.database, GpsPrecision, expireNever);

  const Cache(this.modulId, this.cacheType, this.expireAfter);

  static final Logger logger = Logger.logger<Cache>();

  static const Duration expireImmediately = Duration.zero;
  static const Duration expireAfterOneSecond = Duration(seconds: 1);
  static const Duration expireNever = Duration(days: 36500);

  static final Map<Cache, ValueExpired> _cache = {};

  final Type cacheType;
  final CacheModulId modulId;
  final Duration expireAfter;

  static Cache? byName(String name) {
    for (var key in values) {
      if (key.name == name) {
        return key;
      }
    }
    return null;
  }

  static Future<void> reload() async {
    await SharedCache().reload();
    for (var value in _cache.values) {
      value.expire();
    }
  }

  Future<T> load<T>(T defaultValue) async {
    if (modulId == CacheModulId.database) {
      return await _loadFromDatabase<T>(defaultValue);
    } else {
      return _loadPreference<T>(defaultValue);
    }
  }

  Future<T> save<T>(T value) async {
    StaticCache.update(this, value);
    if (modulId == CacheModulId.sharedPreferences) {
      return await _savePreference<T>(value);
    } else {
      return await _saveToDatabase<T>(value);
    }
  }

  Future<T> _loadFromDatabase<T>(T defaultValue) async {
    _checkType<T>(this);
    if (_cache[this]?.isExpired ?? true) {
      var value = await _getValue<T>(
          cacheModul: DbCache(), key: this, defaultValue: defaultValue);
      _cache[this] = ValueExpired(value: value, duration: expireAfter);
      return value;
    }
    var value = _cache[this]!.value as T;
    return value;
  }

  Future<T> _saveToDatabase<T>(T value) async {
    _checkType<T>(this);
    _cache.addAll({this: ValueExpired(value: value, duration: expireAfter)});
    return await _setValue<T>(cacheModul: DbCache(), key: this, value: value);
  }

  Future<T> _loadPreference<T>(T defaultValue) async {
    _checkType<T>(this);
    return await _getValue<T>(
        cacheModul: SharedCache(), key: this, defaultValue: defaultValue);
  }

  Future<T> _savePreference<T>(T value) async {
    return await _setValue<T>(
        cacheModul: SharedCache(), key: this, value: value);
  }

  static void _checkType<T>(Cache key) {
    if (T != key.cacheType) {
      throw 'setValue::value with type $T on key $key doesn\'t match required type ${key.cacheType} as specified in Cache.enum parameters.';
    }
  }

  static Future<T> _setValue<T>(
      {required CacheModul cacheModul,
      required Cache key,
      required T value}) async {
    //logger.log('save cache key ${key.name}');
    try {
      switch (T) {
        case const (String):
          await cacheModul.setString(key, value as String);
          break;

        case const (List<String>):
          await cacheModul.setStringList(key, value as List<String>);
          break;
        case const (int):
          await cacheModul.setInt(key, value as int);
          break;
        case const (List<int>):
          await cacheModul.setStringList(
              key, TypeAdapter.serializeIntList(value as List<int>));
          break;
        case const (bool):
          await cacheModul.setBool(key, value as bool);
          break;
        case const (double):
          await cacheModul.setDouble(key, value as double);
          break;
        case const (Duration):
          await cacheModul.setInt(
              key, TypeAdapter.serializeDuration(value as Duration));
          break;
        case const (List<CalendarEventId>):
          await cacheModul.setStringList(
              key,
              TypeAdapter.serializeCalendarEventId(
                  value as List<CalendarEventId>));
          break;
        case const (DateTime):
          await cacheModul.setString(
              key, TypeAdapter.serializeDateTime(value as DateTime));
          break;
        case const (GPS):
          await cacheModul.setString(
              key, TypeAdapter.serializeGps(value as GPS));
          break;
        case const (List<GPS>):
          await cacheModul.setStringList(
              key, TypeAdapter.serializeGpsList(value as List<GPS>));
          break;
        case const (List<DateTime>):
          await cacheModul.setStringList(
              key, TypeAdapter.serializeDateTimeList(value as List<DateTime>));
          break;
        case const (TrackingStatus):
          await cacheModul.setString(key,
              TypeAdapter.serializeTrackingStatus(value as TrackingStatus));
          break;
        /* 
        case const (ModelTrackPoint):
          await cacheModul.setString(key,
              TypeAdapter.serializeModelTrackPoint(value as ModelTrackPoint));
          break;
        case const (List<ModelTrackPoint>):
          await cacheModul.setStringList(
              key,
              TypeAdapter.serializeModelTrackPointList(
                  value as List<ModelTrackPoint>));
          break;
        case const (List<ModelAlias>):
          await cacheModul.setStringList(key,
              TypeAdapter.serializeModelAliasList(value as List<ModelAlias>));
          break;
        case const (List<ModelTask>):
          await cacheModul.setStringList(key,
              TypeAdapter.serializeModelTaskList(value as List<ModelTask>));
          break;
        case const (List<ModelUser>):
          await cacheModul.setStringList(key,
              TypeAdapter.serializeModelUserList(value as List<ModelUser>));
          break; */
        case const (OsmLookupConditions):
          await cacheModul.setString(key,
              TypeAdapter.serializeOsmLookup(value as OsmLookupConditions));
          break;
        case const (LocationAccuracy):
          await cacheModul.setString(key,
              TypeAdapter.serializeLocationAccuracy(value as LocationAccuracy));
          break;
        case const (Weekdays):
          await cacheModul.setString(
              key, TypeAdapter.serializeWeekdays(value as Weekdays));
          break;
        case const (DateFormat):
          await cacheModul.setString(
              key, TypeAdapter.serializeDateFormat(value as DateFormat));
          break;
        case const (GpsPrecision):
          await cacheModul.setString(
              key, TypeAdapter.serializeGpsPrecision(value as GpsPrecision));
          break;
        case const (List<SharedTrackpointAlias>):
          await cacheModul.setStringList(
              key,
              TypeAdapter.serializeSharedTrackpointAliasList(
                  value as List<SharedTrackpointAlias>));
          break;
        case const (List<SharedTrackpointUser>):
          await cacheModul.setStringList(
              key,
              TypeAdapter.serializeSharedTrackpointUserList(
                  value as List<SharedTrackpointUser>));
          break;
        case const (List<SharedTrackpointTask>):
          await cacheModul.setStringList(
              key,
              TypeAdapter.serializeSharedTrackpointTaskList(
                  value as List<SharedTrackpointTask>));
          break;
        // ignore: prefer_void_to_null
        case const (Null):
          await cacheModul.remove(key);
          break;

        default:
          throw "Unsupported data type $T";
      }
    } catch (e, stk) {
      logger.error('setValue for $key failed: $e', stk);
    }
    return value;
  }

  static Future<T> _getValue<T>(
      {required CacheModul cacheModul,
      required Cache key,
      required T defaultValue}) async {
    //logger.log('load cache key ${key.name}');
    try {
      switch (T) {
        case const (String):
          return await cacheModul.getString(key) as T? ?? defaultValue;

        case const (List<String>):
          return await cacheModul.getStringList(key) as T? ?? defaultValue;
        case const (int):
          return await cacheModul.getInt(key) as T? ?? defaultValue;
        case const (List<int>):
          return TypeAdapter.deserializeIntList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (bool):
          return await cacheModul.getBool(key) as T? ?? defaultValue;
        case const (double):
          return await cacheModul.getDouble(key) as T? ?? defaultValue;
        case const (Duration):
          return TypeAdapter.deserializeDuration(await cacheModul.getInt(key))
                  as T? ??
              defaultValue;
        case const (DateTime):
          return TypeAdapter.deserializeDateTime(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        case const (List<CalendarEventId>):
          return TypeAdapter.deserializeCalendarEventId(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (GPS):
          return TypeAdapter.deserializeGps(await cacheModul.getString(key))
                  as T? ??
              defaultValue;
        case const (List<GPS>):
          return TypeAdapter.deserializeGpsList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (List<DateTime>):
          return TypeAdapter.deserializeDateTimeList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (TrackingStatus):
          return TypeAdapter.deserializeTrackingStatus(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        /* 
        case const (ModelTrackPoint):
          return TypeAdapter.deserializeModelTrackPoint(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        case const (List<ModelTrackPoint>):
          return TypeAdapter.deserializeModelTrackPointList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (List<ModelAlias>):
          return TypeAdapter.deserializeModelAliasList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (List<ModelTask>):
          return TypeAdapter.deserializeModelTaskList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (List<ModelUser>):
          return TypeAdapter.deserializeModelUserList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue; */
        case const (OsmLookupConditions):
          return TypeAdapter.deserializeOsmLookup(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        case const (LocationAccuracy):
          return TypeAdapter.deserializeLocationAccuracy(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        case const (Weekdays):
          return TypeAdapter.deserializeWeekdays(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        case const (DateFormat):
          return TypeAdapter.deserializeDateFormat(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        case const (GpsPrecision):
          return TypeAdapter.deserializeGpsPrecision(
                  await cacheModul.getString(key)) as T? ??
              defaultValue;
        case const (List<SharedTrackpointAlias>):
          return TypeAdapter.desrializeSharedrackpointAliasList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (List<SharedTrackpointUser>):
          return TypeAdapter.desrializeSharedrackpointUserList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        case const (List<SharedTrackpointTask>):
          return TypeAdapter.desrializeSharedrackpointTaskList(
                  await cacheModul.getStringList(key)) as T? ??
              defaultValue;
        default:
          throw "Unsupported data type $T";
      }
    } catch (e, stk) {
      logger.error('getValue for $key failed - return defaultValue: $e', stk);
      return defaultValue;
    }
  }
}

class CacheTypeAdapter {}
