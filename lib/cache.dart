import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/app_hive.dart';

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
  cacheForegroundTriggerStatus,
  cacheForegroundTrackPointUpdates,
  cacheForegroundActiveTrackPoint,

  /// cache background to forground
  cacheBackgroundTrackingStatus,
  cacheBackgroundLastStatusChange,
  cacheBackgroundLastGps,
  cacheBackgroundGpsPoints,
  cacheBackgroundSmoothGpsPoints,
  cacheBackgroundCalcGpsPoints,
  cacheBackgroundAddress,
  cacheBackgroundRecentTrackpoints,
  cacheBackgroundLastVisitedTrackpoints,

  /// fileHandler
  fileHandlerStoragePath,
  fileHandlerStorageKey,

  /// globals
  globalsWeekDays,
  globalsBackgroundTrackingEnabled,
  globalsPreselectedUsers,
  globalsStatusStandingRequireAlias,
  globalsTrackPointInterval,
  globalsOsmLookupInterval,
  globalsOsmLookupCondition,
  globalsCacheGpsTime,
  globalsDistanceTreshold,
  globalsTimeRangeTreshold,
  globalsAppTickDuration,
  globalsGpsMaxSpeed,
  globalsGpsPointsSmoothCount,

  /// logger
  backgroundLogger;
}

class Cache {
  static final Logger logger = Logger.logger<Cache>();

  /// intList
  static List<String> serializeIntList(List<int> list) {
    return list.map((e) => e.toString()).toList();
  }

  static List<int> deserializeIntList(List<String>? s) {
    return s == null ? [] : s.map((e) => int.parse(e)).toList();
  }

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

  static Future<void> setValue<T>(CacheKeys cacheKey, T value,
      [String Function(T)? serialize]) async {
    final prefs = await SharedPreferences.getInstance();
    String key = cacheKey.name;
    logger.log('setValue $key');
    if (serialize != null) {
      await prefs.setString(key, serialize(value));
      return;
    }
    try {
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
        default:
          throw Exception("Unsupported data type $T");
      }
    } catch (e, stk) {
      logger.error('setValue for $key failed: $e', stk);
    }
  }

  static Future<T> getValue<T>(
    CacheKeys cacheKey,
    T defaultValue, [
    T Function(String)? deserialize,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    String key = cacheKey.name;
    logger.log('getValue $key');
    if (deserialize != null) {
      final stringValue = prefs.getString(key.toString());
      return stringValue != null ? deserialize(stringValue) : defaultValue;
    }
    try {
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

  Cache._();
  static Cache? _instance;
  //factory Cache() => _instance ??= Cache._();
  static Cache get instance => _instance ??= Cache._();

  ///
  /// foreground values
  ///
  List<ModelTrackPoint> trackPointUpdates = [];
  PendingModelTrackPoint pendingTrackPoint =
      PendingModelTrackPoint.pendingTrackPoint;
  bool _triggerStatus = false;
  bool get statusTriggered => _triggerStatus;
  void triggerStatus() => _triggerStatus = true;
  void triggerStatusExecuted() => _triggerStatus = false;

  ///
  /// backround values
  ///
  PendingGps? lastGps;
  // gps list from between trackpoints
  PendingGps? lastStatusChange;
  List<PendingGps> gpsPoints = [];
  List<PendingGps> smoothGpsPoints = [];
  List<PendingGps> calcGpsPoints = [];
  // ignore: prefer_final_fields
  TrackingStatus trackingStatus = TrackingStatus.none;

  String address = '';
  List<ModelTrackPoint> recentTrackPoints = [];
  List<ModelTrackPoint> lastVisitedTrackPoints = [];

  /// forground interval
  /// save foreground, load background and fire event
  static bool _listening = false;
  void stopListen() => _listening = false;
  autoUpdateForeground() {
    if (!_listening) {
      _listening = true;
      Future.microtask(() async {
        while (_listening) {
          try {
            GPS.gps().then((GPS gps) async {
              try {
                await loadBackground(gps);
              } catch (e, stk) {
                logger.error('load background cache failed: $e', stk);
              }
              try {
                /// save foreground
                await saveForeground(gps);
              } catch (e, stk) {
                logger.error('save foreground failed: $e', stk);
              }
              await EventManager.fire<EventOnCacheLoaded>(EventOnCacheLoaded());
            }).onError((error, stackTrace) {
              logger.error('cache listen $error', stackTrace);
            });
          } catch (e, stk) {
            logger.error('gps $e', stk);
          }

          await Future.delayed(Globals.trackPointInterval);
        }
      });
    }
  }

  /// save foreground
  Future<void> saveForeground(GPS gps) async {
    await setValue<PendingModelTrackPoint>(
        CacheKeys.cacheForegroundActiveTrackPoint, pendingTrackPoint);

    await setValue<List<ModelTrackPoint>>(
        CacheKeys.cacheForegroundTrackPointUpdates, trackPointUpdates);

    await setValue<bool>(
        CacheKeys.cacheForegroundTriggerStatus, _triggerStatus);
  }

  /// save foreground
  Future<void> loadForeground(GPS gps) async {
    pendingTrackPoint = await getValue<PendingModelTrackPoint>(
      CacheKeys.cacheForegroundActiveTrackPoint,
      PendingModelTrackPoint.pendingTrackPoint,
    );

    trackPointUpdates = await getValue<List<ModelTrackPoint>>(
        CacheKeys.cacheForegroundTrackPointUpdates, []);

    _triggerStatus =
        await getValue<bool>(CacheKeys.cacheForegroundTriggerStatus, false);
  }

  /// load background
  Future<void> loadBackground(GPS gps) async {
    recentTrackPoints = await getValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundRecentTrackpoints, []);

    lastVisitedTrackPoints = await getValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundLastVisitedTrackpoints, []);

    address = await getValue<String>(CacheKeys.cacheBackgroundAddress, '');

    calcGpsPoints = await getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundCalcGpsPoints, []);

    gpsPoints = await getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundGpsPoints, []);

    lastGps = await getValue<PendingGps>(
        CacheKeys.cacheBackgroundLastGps, PendingGps(gps.lat, gps.lon));

    lastStatusChange = await getValue<PendingGps>(
        CacheKeys.cacheBackgroundLastStatusChange,
        PendingGps(gps.lat, gps.lon));

    smoothGpsPoints = await getValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundSmoothGpsPoints, []);

    trackingStatus = await getValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.none);
  }

  /// load background
  Future<void> saveBackground(GPS gps) async {
    //
    await setValue<TrackingStatus>(
        CacheKeys.cacheBackgroundTrackingStatus, TrackingStatus.none);

    await setValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundRecentTrackpoints, recentTrackPoints);

    await setValue<List<ModelTrackPoint>>(
        CacheKeys.cacheBackgroundLastVisitedTrackpoints,
        lastVisitedTrackPoints);

    await setValue<String>(CacheKeys.cacheBackgroundAddress, address);

    await setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundGpsPoints, gpsPoints);

    await setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundSmoothGpsPoints, smoothGpsPoints);

    await setValue<List<PendingGps>>(
        CacheKeys.cacheBackgroundCalcGpsPoints, calcGpsPoints);

    await setValue<PendingGps>(CacheKeys.cacheBackgroundLastGps,
        lastGps ?? PendingGps(gps.lat, gps.lon));

    await setValue<PendingGps>(CacheKeys.cacheBackgroundLastStatusChange,
        lastStatusChange ?? PendingGps(gps.lat, gps.lon));
  }
}
