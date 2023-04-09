import 'package:chaostours/globals.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:chaostours/logger.dart';

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
  final Box _box;
  AppHive._handler(this._box);

  static Future<void> accessBox(
      {required AppHiveNames boxName,
      required Future<void> Function(AppHive box) access}) async {
    Box box = await _openBox(boxName);
    await access(AppHive._handler(box));
    //box.close();
  }

  ///
  /// value is default value
  read<T>({required AppHiveKeys hiveKey, required T value}) {
    logger.log('read appHive ${_box.name}:${hiveKey.name} ');
    var vg = _box.get(hiveKey.name);
    if (T.toString() == 'Null') {
      return vg;
    }
    return vg == null ? value : castRead<T>(vg);
  }

  write<T>(
      {required AppHiveKeys hiveKey, required dynamic value, Type? castAs}) {
    logger.log('write appHive ${_box.name}:${hiveKey.name}');
    dynamic v = castWrite(value, castAs);
    _box.put(hiveKey.name, v);
  }

  static Future<void> init(String prefix) async {
    await Hive.initFlutter();
  }

  static T castRead<T>(dynamic value) {
    Type t = value.runtimeType;
    if (t == T) {
      return value as T;
    }
    if (hiveTypes.contains(T)) {
      throw 'Unsupported Hive Type cast from $t to $T\n'
          'Solution: Add cast for Type $T in AppHive::castRead and castWrite Type as String';
    }
    if (t != String) {
      throw 'cast type must be string';
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

  static dynamic castWrite(dynamic value, [Type? tf]) {
    Type tv = value.runtimeType;
    if (hiveTypes.contains(tv)) {
      return value;
    }
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
