import 'package:chaostours/globals.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:chaostours/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppHiveNames {
  cacheForground,
  cacheBackground,
  fileHandler,
  globalsAppSettings,
  eventManager;
}

enum AppHiveKeys {
  /// cache forground to background
  cacheForegroundTriggerStatus,
  cacheForegroundTrackPointUpdates,
  cacheForegroundActiveTrackPoint,

  /// cache background to forground
  cacheBackgroundStatus,
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
  globalsGsmLookupInterval,
  globalsOsmLookupCondition,
  globalsCacheGpsTime,
  globalsDistanceTreshold,
  globalsTimeRangeTreshold,
  globalsAppTickDuration,
  globalsGpsMaxSpeed,
  globalsGpsPointsSmoothCount;
}

class AppHive {
  static final Logger logger = Logger.logger<AppHive>();
  static const List<Type> hiveTypes = [
    int,
    double,
    bool,
    String,
    List<int>,
    List<String>,
    Map<String, String>,
    Map<String, int>,
    Map<String, double>,
    Map<int, String>,
    Map<double, String>
  ];
  final SharedPreferences _box;
  AppHive._handler(this._box);

  static Future<void> accessBox(
      {required AppHiveNames boxName,
      required Future<void> Function(AppHive box) access}) async {
    var box = await SharedPreferences.getInstance();
    await box.reload();
    await access(AppHive._handler(box));
  }

/*
  static Future<void> _accessBox(
      {required AppHiveNames boxName,
      required Future<void> Function(AppHive box) access}) async {
    Box box = await _openBox(boxName);
    await access(AppHive._handler(box));
    await box.close();
  }
*/
  ///
  /// value is default value
  read<T>({required AppHiveKeys key, required T value}) {
    var k = key.name;
    String? vg;
    logger.log('read shared $k');

    switch (T) {
      case bool:
        return (_box.getBool(k) ?? value) as T;
      case int:
        return (_box.getInt(k) ?? value) as T;
      case double:
        return (_box.getDouble(k) ?? value) as T;
      case List<String>:
        return (_box.getStringList(k) ?? value) as T;
      default:
        vg = _box.getString(k);
    }
    if (T.toString() == 'Null') {
      return vg;
    }
    return vg == null ? value : castRead<T>(vg);
  }

  Future<dynamic> write<T>(
      {required AppHiveKeys key, required dynamic value, Type? castAs}) async {
    var k = key.name;
    logger.log('write shared $k');
    if (value == null) {
      throw 'write not null to sharedPreferences';
    }
    switch (T) {
      case bool:
        return await _box.setBool(k, value);
      case int:
        return await _box.setInt(k, value);
      case double:
        return await _box.setDouble(k, value);
      case String:
        return await _box.setString(k, value);
      case List<String>:
        return await _box.setStringList(k, value);
      default:
        value = castWrite(value, castAs);
        return await _box.setString(k, value);
    }
  }

  static Future<void> init(String prefix) async {
    await Hive.initFlutter();
  }

  static T castRead<T>(dynamic value) {
    Type t = value.runtimeType;
    if (t == T) {
      return value as T;
    }
    var s = T.toString();
    switch (s) {
      case 'DateTime':
        return DateTime.parse(value) as T;
      case 'Duration':
        return Duration(seconds: int.parse(value)) as T;
      case 'OsmLookup':
        return OsmLookup.values.byName(value) as T;
      default:
        throw "Type T: $T not implemented";
    }
  }

  static String castWrite(dynamic value, [Type? tf]) {
    Type tv = value.runtimeType;
    Type t = tf ?? tv;
    var s = t.toString();
    switch (s) {
      case 'DateTime':
        return (value as DateTime).toIso8601String();
      case 'Duration':
        return (value as Duration).inSeconds.toString();
      case 'OsmLookup':
        return (value as OsmLookup).name;
      default:
        throw "Type T: $t not implemented";
    }
  }

  static Future<T> readKeyFromName<T>(
      {required AppHiveNames hiveName,
      required AppHiveKeys hiveKey,
      required T defaultValue}) async {
    Box box = await _openBox(hiveName);
    var v = box.get(hiveKey.name);
    T value = castRead<T>(v ?? defaultValue);
    box.close();
    return value;
  }

  static Future<void> writeKeyToName<T>(
      {required AppHiveNames hiveName,
      required AppHiveKeys hiveKey,
      required dynamic value,
      Type? castAs}) async {
    dynamic v = castWrite(value, castAs);
    Box box = await _openBox(hiveName);
    box.put(hiveKey.name, v);
    box.close();
  }

  static Future<Box> _openBox(AppHiveNames boxName) async {
    String n = boxName.name;
    try {
      if (Hive.isBoxOpen(n)) {
        return Hive.box(n);
      }
      if (await Hive.boxExists(n) && !Hive.isBoxOpen(n)) {
        await Hive.openBox(n);
        return Hive.box(n);
      }
    } catch (e, stk) {
      logger.error(e, stk);
    }

    Box b;

    try {
      b = Hive.box(n);
    } catch (e) {
      logger.log(e);
      while (true) {
        try {
          b = await Hive.openBox(n);
          break;
        } catch (e) {
          logger.log(e);
          // take a breath and try again
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }
    return b;
  }
}
