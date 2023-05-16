import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';

/*
enum JsonKeys {
  // background status and messages
  bgStatus,
  bgLastStatusChange,
  bgLastGps,
  bgGpsPoints,
  bgSmoothGpsPoints,
  bgCalcGpsPoints,
  bgAddress,
  // forground messages for background
  fgTriggerStatus,
  fgTrackPointUpdates,
  fgActiveTrackPoint;
}
*/
enum CacheKeys {
  /// cache foreground to background
  /// saved only on special event triggered by user
  cacheTriggerTrackingStatus(TrackingStatus),

  /// saved only on special events
  cacheEventBackgroundGpsStartMoving(PendingGps),
  cacheEventBackgroundGpsStartStanding(PendingGps),
  cacheEventBackgroundGpsLastStatusChange(PendingGps),

  /// cache background to forground
  cacheBackgroundTrackingStatus(TrackingStatus),
  cacheBackgroundAliasIdList(List<int>),
  cacheBackgroundUserIdList(List<int>),
  cacheBackgroundTaskIdList(List<int>),
  cacheBackgroundTrackPointUserNotes(String),
  cacheBackgroundLastGps(PendingGps),
  cacheBackgroundGpsPoints(List<PendingGps>),
  cacheBackgroundSmoothGpsPoints(List<PendingGps>),
  cacheBackgroundCalcGpsPoints(List<PendingGps>),
  cacheBackgroundAddress(String),

  /// cache database
  tableModelTrackpoint(List<ModelTrackPoint>),
  tableModelAlias(List<ModelAlias>),
  tableModelUser(List<ModelUser>),
  tableModelTask(List<ModelTask>),

  /// eventCalendar
  /// "id\tname\taccount"
  selectedCalendarId(String),
  lastCalendarEventId(String),

  /// globals
  globalsWeekDays(List<String>),
  globalsBackgroundTrackingEnabled(bool),
  globalsStatusStandingRequireAlias(bool),
  globalsTrackPointInterval(Duration),
  globalsOsmLookupCondition(OsmLookup),
  globalsCacheGpsTime(Duration),
  globalsDistanceTreshold(int),
  globalsTimeRangeTreshold(Duration),
  globalsAppTickDuration(Duration),
  globalsGpsMaxSpeed(int),
  globalsGpsPointsSmoothCount(int),

  /// logger
  backgroundLogger(List<String>);

  final Type cacheType;
  const CacheKeys(this.cacheType);
}

class Cache {
  static final Logger logger = Logger.logger<Cache>();

  Cache._();
  static Cache? _instance;
  factory Cache() => _instance ??= Cache._();
  static Cache get instance => _instance ??= Cache._();

  static Future<void> reload() async {
    await (await SharedPreferences.getInstance()).reload();
  }

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

  /// pending gps list
  static List<String> serializePendingGpsList(List<PendingGps> gpsList) {
    return gpsList.map((e) => e.toSharedString()).toList();
  }

  static List<PendingGps>? deserializePendingGpsList(List<String>? list) {
    return list == null
        ? []
        : list.map((e) => PendingGps.toSharedObject(e)).toList();
  }

  /// gps list
  static List<String> serializeGpsList(List<GPS> gpsList) {
    return gpsList.map((e) => e.toString()).toList();
  }

  static List<GPS>? deserializeGpsList(List<String>? list) {
    return list == null ? [] : list.map((e) => GPS.toObject(e)).toList();
  }

  /// pending GPS
  static String serializePendingGPS(PendingGps gps) => gps.toSharedString();
  static GPS? deserializePendingGps(String? gps) =>
      gps == null ? null : PendingGps.toSharedObject(gps);

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

  /// PendingModelTrackPoint
  static String serializePendingModelTrackPoint(PendingModelTrackPoint tp) =>
      tp.toSharedString();
  static PendingModelTrackPoint? deserializePendingModelTrackPoint(
          String? tp) =>
      tp == null ? null : PendingModelTrackPoint.toSharedModel(tp);

  // ModelTrackPoint
  static String serializeModelTrackPoint(ModelTrackPoint tp) => tp.toString();
  static ModelTrackPoint? deserializeModelTrackPoint(String? tp) =>
      tp == null ? null : ModelTrackPoint.toModel(tp);

  /// List ModelAlias
  static List<String> serializeModelAliasList(List<ModelAlias> tpList) =>
      tpList.map((e) => e.toString()).toList();
  static List<ModelAlias>? deserializeModelAliasList(List<String>? list) =>
      list == null ? [] : list.map((e) => ModelAlias.toModel(e)).toList();

  /// List ModelUser
  static List<String> serializeModelUserList(List<ModelUser> tpList) =>
      tpList.map((e) => e.toString()).toList();
  static List<ModelUser>? deserializeModelUserList(List<String>? list) =>
      list == null ? [] : list.map((e) => ModelUser.toModel(e)).toList();

  /// List ModelTask
  static List<String> serializeModelTaskList(List<ModelTask> tpList) =>
      tpList.map((e) => e.toString()).toList();
  static List<ModelTask>? deserializeModelTaskList(List<String>? list) =>
      list == null ? [] : list.map((e) => ModelTask.toModel(e)).toList();

  /// List ModelTrackPoint
  static List<String> serializeModelTrackPointList(
          List<ModelTrackPoint> tpList) =>
      tpList.map((e) => e.toString()).toList();
  static List<ModelTrackPoint>? deserializeModelTrackPointList(
          List<String>? list) =>
      list == null ? [] : list.map((e) => ModelTrackPoint.toModel(e)).toList();

  /// List PendingModelTrackPoint
  static List<String> serializePendingModelTrackPointList(
          List<PendingModelTrackPoint> tpList) =>
      tpList.map((e) => e.toSharedString()).toList();
  static List<PendingModelTrackPoint>? desrializePendingModelTrackPointList(
          List<String>? list) =>
      list == null
          ? []
          : list.map((e) => PendingModelTrackPoint.toSharedModel(e)).toList();

  /// OSMLookup
  static String serializeOsmLookup(OsmLookup lo) => lo.name;
  static OsmLookup? deserializeOsmLookup(String? osm) =>
      osm == null ? OsmLookup.never : OsmLookup.values.byName(osm);

  /// IntMap
  static const intSeparator = ',';
  static String serializeIntSet(Set<int> se) => se.join(intSeparator);
  static Set<int> deserializeIntSet(String se) {
    Set<int> set = {};
    if (se.trim().isEmpty) {
      return set;
    }
    for (var i in se.split(intSeparator)) {
      set.add(int.parse(i));
    }
    return set;
  }

  static Future<T> setValue<T>(CacheKeys cacheKey, T value) async {
    final prefs = await SharedPreferences.getInstance();
    String key = cacheKey.name;
    try {
      if (T != cacheKey.cacheType) {
        throw Exception(
            'setValue::value with type $T on key $key doesn\'t match required type ${cacheKey.cacheType}');
      }
      switch (T) {
        case String:
          await prefs.setString(key, value as String);
          break;
        case List<String>:
          await prefs.setStringList(key.toString(), value as List<String>);
          break;
        case int:
          await prefs.setInt(key, value as int);
          break;
        case List<int>:
          await prefs.setStringList(key, serializeIntList(value as List<int>));
          break;
        case bool:
          await prefs.setBool(key, value as bool);
          break;
        case double:
          await prefs.setDouble(key, value as double);
          break;
        case Duration:
          await prefs.setInt(key, serializeDuration(value as Duration));
          break;
        case DateTime:
          await prefs.setString(key, serializeDateTime(value as DateTime));
          break;
        case GPS:
          await prefs.setString(key, serializeGps(value as GPS));
          break;
        case List<GPS>:
          await prefs.setStringList(key, serializeGpsList(value as List<GPS>));
          break;
        case PendingGps:
          await prefs.setString(key, serializePendingGPS(value as PendingGps));
          break;
        case List<PendingGps>:
          await prefs.setStringList(
              key, serializePendingGpsList(value as List<PendingGps>));
          break;
        case TrackingStatus:
          await prefs.setString(
              key, serializeTrackingStatus(value as TrackingStatus));
          break;
        case ModelTrackPoint:
          await prefs.setString(
              key, serializeModelTrackPoint(value as ModelTrackPoint));
          break;
        case List<ModelTrackPoint>:
          await prefs.setStringList(key,
              serializeModelTrackPointList(value as List<ModelTrackPoint>));
          break;
        case List<ModelAlias>:
          await prefs.setStringList(
              key, serializeModelAliasList(value as List<ModelAlias>));
          break;
        case List<ModelTask>:
          await prefs.setStringList(
              key, serializeModelTaskList(value as List<ModelTask>));
          break;
        case List<ModelUser>:
          await prefs.setStringList(
              key, serializeModelUserList(value as List<ModelUser>));
          break;
        case PendingModelTrackPoint:
          await prefs.setString(key,
              serializePendingModelTrackPoint(value as PendingModelTrackPoint));
          break;
        case List<PendingModelTrackPoint>:
          await prefs.setStringList(
              key,
              serializePendingModelTrackPointList(
                  value as List<PendingModelTrackPoint>));
          break;
        case OsmLookup:
          await prefs.setString(key, serializeOsmLookup(value as OsmLookup));
          break;
        case Null:
          await prefs.remove(key);
          break;
        default:
          throw Exception("Unsupported data type $T");
      }
    } catch (e, stk) {
      logger.error('setValue for $key failed: $e', stk);
    }
    return value;
  }

  static Future<T> getValue<T>(CacheKeys cacheKey, T defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    String key = cacheKey.name;
    try {
      if (T != cacheKey.cacheType) {
        throw Exception(
            'getValue::value with type $T on key $key doesn\'t match required type ${cacheKey.cacheType}');
      }
      switch (T) {
        case String:
          return prefs.getString(key) as T? ?? defaultValue;

        case List<String>:
          return prefs.getStringList(key) as T? ?? defaultValue;
        case int:
          return prefs.getInt(key) as T? ?? defaultValue;
        case List<int>:
          return deserializeIntList(prefs.getStringList(key)) as T? ??
              defaultValue;
        case bool:
          return prefs.getBool(key) as T? ?? defaultValue;
        case double:
          return prefs.getDouble(key) as T? ?? defaultValue;
        case Duration:
          return deserializeDuration(prefs.getInt(key)) as T? ?? defaultValue;
        case DateTime:
          return deserializeDateTime(prefs.getString(key)) as T? ??
              defaultValue;
        case GPS:
          return deserializeGps(prefs.getString(key)) as T? ?? defaultValue;
        case List<GPS>:
          return deserializeGpsList(prefs.getStringList(key)) as T? ??
              defaultValue;
        case PendingGps:
          return deserializePendingGps(prefs.getString(key)) as T? ??
              defaultValue;
        case List<PendingGps>:
          return deserializePendingGpsList(prefs.getStringList(key)) as T? ??
              defaultValue;
        case TrackingStatus:
          return deserializeTrackingStatus(prefs.getString(key)) as T? ??
              defaultValue;
        case ModelTrackPoint:
          return deserializeModelTrackPoint(prefs.getString(key)) as T? ??
              defaultValue;
        case List<ModelTrackPoint>:
          return deserializeModelTrackPointList(prefs.getStringList(key))
                  as T? ??
              defaultValue;
        case List<ModelAlias>:
          return deserializeModelAliasList(prefs.getStringList(key)) as T? ??
              defaultValue;
        case List<ModelTask>:
          return deserializeModelTaskList(prefs.getStringList(key)) as T? ??
              defaultValue;
        case List<ModelUser>:
          return deserializeModelUserList(prefs.getStringList(key)) as T? ??
              defaultValue;
        case PendingModelTrackPoint:
          return deserializePendingModelTrackPoint(prefs.getString(key))
                  as T? ??
              defaultValue;
        case List<PendingModelTrackPoint>:
          return desrializePendingModelTrackPointList(prefs.getStringList(key))
                  as T? ??
              defaultValue;
        case OsmLookup:
          return deserializeOsmLookup(prefs.getString(key)) as T? ??
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
