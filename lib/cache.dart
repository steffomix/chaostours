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

// import 'package:shared_preferences/shared_preferences.dart';

///
import 'package:chaostours/model/model_cache.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/value_expired.dart';
import 'package:geolocator/geolocator.dart';

enum Cache {
  /// trigger off == TrackingStatus.none
  /// triggered by user, set to none in background
  trackingStatusTriggered(TrackingStatus),

  /// updated on every second in foreground
  foregroundAliasIdList(List<int>),

  // background task
  backgroundLastTick(DateTime),
  backgroundTickList(List<DateTime>),

  /// status change events
  backgroundGpsStartMoving(GPS),
  backgroundGpsStartStanding(GPS),
  backgroundGpsLastStatusChange(GPS),

  /// cache background to forground
  backgroundTrackingStatus(TrackingStatus),

  /// user input
  backgroundAliasIdList(List<int>),
  backgroundUserIdList(List<int>),
  backgroundTaskIdList(List<int>),
  backgroundTrackPointUserNotes(String),

  /// tracking detection
  backgroundLastGps(GPS),
  backgroundGpsPoints(List<GPS>),
  backgroundGpsSmoothPoints(List<GPS>),
  backgroundGpsCalcPoints(List<GPS>),

  /// address updated on each backgroiund tick - if activated
  backgroundAddress(String),

  /// address updated on status change - if activated
  backgroundLastStandingAddress(String),

  /// eventCalendar
  backgroundCalendarLastEventIds(List<CalendarEventId>),

  /// appUserStettings
  appSettingBackgroundTrackingEnabled(bool, Duration(days: 365)),
  appSettingStatusStandingRequireAlias(bool, Duration(days: 365)),
  appSettingAutocreateAliasDuration(Duration, Duration(days: 365)),
  appSettingAutocreateAlias(bool, Duration(days: 365)),
  appSettingForegroundUpdateInterval(Duration, Duration(days: 365)),
  appSettingOsmLookupCondition(OsmLookupConditions, Duration(days: 365)),
  appSettingCacheGpsTime(Duration, Duration(days: 365)),
  appSettingLocationAccuracy(LocationAccuracy, Duration(days: 365)),
  appSettingDistanceTreshold(int, Duration(days: 365)),
  appSettingTimeRangeTreshold(Duration, Duration(days: 365)),
  appSettingBackgroundTrackingInterval(Duration, Duration(days: 365)),
  appSettingGpsPointsSmoothCount(int, Duration(days: 365)),
  appSettingPublishToCalendar(bool, Duration(days: 365)),
  appSettingTimeZone(String, Duration(days: 365)),
  appSettingWeekdays(Weekdays, Duration(days: 365));

  Future<T> load<T>(T fallback) async {
    if (_cache[this]?.expired ?? true) {
      var value = await CacheTypeAdapter.getValue<T>(this, fallback);
      _cache[this] = ValueExpired(value: value, duration: expireAfter);
      return value;
    }
    return _cache[this]!.value as T;
  }

  Future<T> save<T>(T value) async {
    _cache.addAll({this: ValueExpired(value: value, duration: expireAfter)});
    return await CacheTypeAdapter.setValue<T>(this, value);
  }

  static final Map<Cache, ValueExpired> _cache = {};

  final Type cacheType;
  final Duration expireAfter;
  const Cache(this.cacheType, [this.expireAfter = Duration.zero]);

  int get id => index + 1;

  static Cache? byName(String name) {
    for (var key in values) {
      if (key.name == name) {
        return key;
      }
    }
    return null;
  }
}

class CacheTypeAdapter {
  static final Logger logger = Logger.logger<CacheTypeAdapter>();

  /// intList
  static List<String> serializeIntList(List<int> list) =>
      list.map((e) => e.toString()).toList();
  static List<int> deserializeIntList(List<String>? s) =>
      s == null ? [] : s.map((e) => int.parse(e)).toList();

  /// DateTime
  static String serializeDateTime(DateTime dateTime) =>
      dateTime.toIso8601String();
  static DateTime? deserializeDateTime(String? time) =>
      time == null ? null : DateTime.parse(time);

  /// Duration
  static int serializeDuration(Duration duration) => duration.inSeconds;
  static Duration? deserializeDuration(int? seconds) =>
      seconds == null ? null : Duration(seconds: seconds);

  /// CalendarEventId
  static List<String> serializeCalendarEventId(List<CalendarEventId> ids) =>
      ids.map((e) => e.toString()).toList();
  static List<CalendarEventId> deserializeCalendarEventId(List<String>? ids) =>
      ids == null ? [] : ids.map((s) => CalendarEventId.toObject(s)).toList();

  /// gps list
  static List<String> serializeGpsList(List<GPS> gpsList) {
    return gpsList.map((e) => e.toString()).toList();
  }

  static List<GPS>? deserializeGpsList(List<String>? list) {
    return list == null ? [] : list.map((e) => GPS.toObject(e)).toList();
  }

  /// DateTime list
  static List<String> serializeDateTimeList(List<DateTime> gpsList) {
    return gpsList.map((e) => e.toIso8601String()).toList();
  }

  static List<DateTime>? deserializeDateTimeList(List<String>? list) {
    return list == null ? [] : list.map((e) => DateTime.parse(e)).toList();
  }

  /// GPS
  static String serializeGps(GPS gps) => gps.toString();
  static GPS? deserializeGps(String? gps) =>
      gps == null ? null : GPS.toObject(gps);

  /// trackingstatus
  static String serializeTrackingStatus(TrackingStatus t) {
    return t.name;
  }

  static TrackingStatus? deserializeTrackingStatus(String? s) {
    return s == null ? null : TrackingStatus.values.byName(s);
  }

  // ModelTrackPoint
  static String serializeModelTrackPoint(ModelTrackPoint tp) =>
      Model.toJson(tp.toMap());
  static ModelTrackPoint? deserializeModelTrackPoint(String? tp) =>
      tp == null ? null : ModelTrackPoint.fromMap(Model.fromJson(tp));

  /// List ModelAlias
  static List<String> serializeModelAliasList(List<ModelAlias> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelAlias>? deserializeModelAliasList(List<String>? list) =>
      list == null
          ? []
          : list.map((e) => ModelAlias.fromMap(Model.fromJson(e))).toList();

  /// List ModelUser
  static List<String> serializeModelUserList(List<ModelUser> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelUser>? deserializeModelUserList(List<String>? list) =>
      list == null
          ? []
          : list.map((e) => ModelUser.fromMap(Model.fromJson(e))).toList();

  /// List ModelTask
  static List<String> serializeModelTaskList(List<ModelTask> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelTask>? deserializeModelTaskList(List<String>? list) =>
      list == null
          ? []
          : list.map((e) => ModelTask.fromMap(Model.fromJson(e))).toList();

  /// List ModelTrackPoint
  static List<String> serializeModelTrackPointList(
          List<ModelTrackPoint> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelTrackPoint>? deserializeModelTrackPointList(
          List<String>? list) =>
      list == null
          ? []
          : list
              .map((e) => ModelTrackPoint.fromMap(Model.fromJson(e)))
              .toList();

  /// OSMLookup
  static String serializeOsmLookup(OsmLookupConditions o) => o.name;
  static OsmLookupConditions? deserializeOsmLookup(String? osm) => osm == null
      ? OsmLookupConditions.never
      : OsmLookupConditions.values.byName(osm);

  /// OSMLookup
  static String serializeLocationAccuracy(LocationAccuracy o) => o.name;
  static LocationAccuracy? deserializeLocationAccuracy(String? acc) =>
      acc == null ? LocationAccuracy.best : LocationAccuracy.values.byName(acc);

  /// OSMWeekdays
  static String serializeWeekdays(Weekdays o) => o.name;
  static Weekdays? deserializeWeekdays(String? osm) =>
      osm == null ? Weekdays.mondayFirst : Weekdays.values.byName(osm);

  static Future<T> setValue<T>(Cache key, T value) async {
    logger.log('save cache key ${key.name}');
    try {
      if (T != key.cacheType) {
        throw Exception(
            'setValue::value with type $T on key $key doesn\'t match required type ${key.cacheType}');
      }
      switch (T) {
        case String:
          await DbCache.setString(key, value as String);
          break;

        case const (List<String>):
          await DbCache.setStringList(key, value as List<String>);
          break;
        case int:
          await DbCache.setInt(key, value as int);
          break;
        case const (List<int>):
          await DbCache.setStringList(
              key, serializeIntList(value as List<int>));
          break;
        case bool:
          await DbCache.setBool(key, value as bool);
          break;
        case double:
          await DbCache.setDouble(key, value as double);
          break;
        case Duration:
          await DbCache.setInt(key, serializeDuration(value as Duration));
          break;
        case const (List<CalendarEventId>):
          await DbCache.setStringList(
              key, serializeCalendarEventId(value as List<CalendarEventId>));
          break;
        case DateTime:
          await DbCache.setString(key, serializeDateTime(value as DateTime));
          break;
        case GPS:
          await DbCache.setString(key, serializeGps(value as GPS));
          break;
        case const (List<GPS>):
          await DbCache.setStringList(
              key, serializeGpsList(value as List<GPS>));
          break;
        case const (List<DateTime>):
          await DbCache.setStringList(
              key, serializeDateTimeList(value as List<DateTime>));
          break;
        case TrackingStatus:
          await DbCache.setString(
              key, serializeTrackingStatus(value as TrackingStatus));
          break;
        case ModelTrackPoint:
          await DbCache.setString(
              key, serializeModelTrackPoint(value as ModelTrackPoint));
          break;
        case const (List<ModelTrackPoint>):
          await DbCache.setStringList(key,
              serializeModelTrackPointList(value as List<ModelTrackPoint>));
          break;
        case const (List<ModelAlias>):
          await DbCache.setStringList(
              key, serializeModelAliasList(value as List<ModelAlias>));
          break;
        case const (List<ModelTask>):
          await DbCache.setStringList(
              key, serializeModelTaskList(value as List<ModelTask>));
          break;
        case const (List<ModelUser>):
          await DbCache.setStringList(
              key, serializeModelUserList(value as List<ModelUser>));
          break;
        case OsmLookupConditions:
          await DbCache.setString(
              key, serializeOsmLookup(value as OsmLookupConditions));
          break;
        case LocationAccuracy:
          await DbCache.setString(
              key, serializeLocationAccuracy(value as LocationAccuracy));
          break;
        case Weekdays:
          await DbCache.setString(key, serializeWeekdays(value as Weekdays));
          break;
        // ignore: prefer_void_to_null
        case Null:
          await DbCache.remove(key);
          break;

        default:
          throw Exception("Unsupported data type $T");
      }
    } catch (e, stk) {
      logger.error('setValue for $key failed: $e', stk);
    }
    return value;
  }

  static Future<T> getValue<T>(Cache key, T defaultValue) async {
    logger.log('load cache key ${key.name}');
    try {
      if (T != key.cacheType) {
        throw Exception(
            'getValue::value with type $T on key $key doesn\'t match required type ${key.cacheType}');
      }
      switch (T) {
        case String:
          return await DbCache.getString(key) as T? ?? defaultValue;

        case const (List<String>):
          return await DbCache.getStringList(key) as T? ?? defaultValue;
        case int:
          return await DbCache.getInt(key) as T? ?? defaultValue;
        case const (List<int>):
          return deserializeIntList(await DbCache.getStringList(key)) as T? ??
              defaultValue;
        case bool:
          return await DbCache.getBool(key) as T? ?? defaultValue;
        case double:
          return await DbCache.getDouble(key) as T? ?? defaultValue;
        case Duration:
          return deserializeDuration(await DbCache.getInt(key)) as T? ??
              defaultValue;
        case DateTime:
          return deserializeDateTime(await DbCache.getString(key)) as T? ??
              defaultValue;
        case const (List<CalendarEventId>):
          return deserializeCalendarEventId(await DbCache.getStringList(key))
                  as T? ??
              defaultValue;
        case GPS:
          return deserializeGps(await DbCache.getString(key)) as T? ??
              defaultValue;
        case const (List<GPS>):
          return deserializeGpsList(await DbCache.getStringList(key)) as T? ??
              defaultValue;
        case const (List<DateTime>):
          return deserializeDateTimeList(await DbCache.getStringList(key))
                  as T? ??
              defaultValue;
        case TrackingStatus:
          return deserializeTrackingStatus(await DbCache.getString(key))
                  as T? ??
              defaultValue;
        case ModelTrackPoint:
          return deserializeModelTrackPoint(await DbCache.getString(key))
                  as T? ??
              defaultValue;
        case const (List<ModelTrackPoint>):
          return deserializeModelTrackPointList(
                  await DbCache.getStringList(key)) as T? ??
              defaultValue;
        case const (List<ModelAlias>):
          return deserializeModelAliasList(await DbCache.getStringList(key))
                  as T? ??
              defaultValue;
        case const (List<ModelTask>):
          return deserializeModelTaskList(await DbCache.getStringList(key))
                  as T? ??
              defaultValue;
        case const (List<ModelUser>):
          return deserializeModelUserList(await DbCache.getStringList(key))
                  as T? ??
              defaultValue;
        case OsmLookupConditions:
          return deserializeOsmLookup(await DbCache.getString(key)) as T? ??
              defaultValue;
        case LocationAccuracy:
          return deserializeLocationAccuracy(await DbCache.getString(key))
                  as T? ??
              defaultValue;
        case Weekdays:
          return deserializeWeekdays(await DbCache.getString(key)) as T? ??
              defaultValue;

        default:
          throw Exception("Unsupported data type $T");
      }
    } catch (e, stk) {
      logger.error('getValue for $key failed - return defaultValue: $e', stk);
      return defaultValue;
    }
  }
}
