import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/app_hive.dart';

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

class Cache {
  static Logger logger = Logger.logger<Cache>();
  Cache._();
  static Cache? _instance;
  //factory Cache() => _instance ??= Cache._();
  static Cache get instance => _instance ??= Cache._();

  ///
  /// foreground values
  ///
  List<ModelTrackPoint> trackPointUpdates = [];
  ModelTrackPoint pendingTrackPoint = ModelTrackPoint.pendingTrackPoint;
  bool _triggerStatus = false;
  bool get statusTriggered => _triggerStatus;
  void triggerStatus() => _triggerStatus = true;
  void triggerStatusExecuted() => _triggerStatus = false;

  ///
  /// backround values
  ///
  GPS? lastGps;
  // gps list from between trackpoints
  GPS? lastStatusChange;
  List<GPS> gpsPoints = [];
  List<GPS> smoothGpsPoints = [];
  List<GPS> calcGpsPoints = [];
  // ignore: prefer_final_fields
  TrackingStatus _status = TrackingStatus.none;
  TrackingStatus get status => _status;

  String address = '';
  List<ModelTrackPoint> recentTrackPoints = [];
  List<ModelTrackPoint> localTrackPoints = [];

  /// forground interval
  /// save foreground, load background and fire event
  static bool _listening = false;
  void stopListen() => _listening = false;
  listen() {
    if (!_listening) {
      _listening = true;
      Future.microtask(() async {
        while (_listening) {
          GPS.gps().then((GPS gps) {
            try {
              loadBackground(gps);
            } catch (e, stk) {
              logger.error('load background cache failed: $e', stk);
            }
            try {
              /// save foreground
              saveForeground(gps);
            } catch (e, stk) {
              logger.error('save foreground failed: $e', stk);
            }
          }).onError((error, stackTrace) {
            logger.error('cache listen $error', stackTrace);
          });
        }
      });
    }
  }

  /// save foreground
  Future<void> saveForeground(GPS gps) async {
    await AppHive.accessBox(
        boxName: AppHiveNames.cacheForground,
        access: (AppHive box) async {
          box.write<String>(
              hiveKey: AppHiveKeys.cacheForegroundActiveTrackPoint,
              value: pendingTrackPoint.toSharedString());

          box.write<List<String>>(
              hiveKey: AppHiveKeys.cacheForegroundTrackPointUpdates,
              value: trackPointUpdates.map((e) => e.toSharedString()).toList());

          box.write<bool>(
              hiveKey: AppHiveKeys.cacheForegroundTriggerStatus,
              value: _triggerStatus);
          _triggerStatus = false;
        });
  }

  /// save foreground
  Future<void> loadForeground(GPS gps) async {
    await AppHive.accessBox(
        boxName: AppHiveNames.cacheForground,
        access: (AppHive box) async {
          pendingTrackPoint = ModelTrackPoint.toSharedModel(box.read<String>(
              hiveKey: AppHiveKeys.cacheForegroundActiveTrackPoint,
              value: ModelTrackPoint.pendingTrackPoint.toSharedString()));

          trackPointUpdates = (box.read<List<String>>(
                  hiveKey: AppHiveKeys.cacheForegroundTrackPointUpdates,
                  value: []) as List<String>)
              .map((e) => ModelTrackPoint.toSharedModel(e))
              .toList();

          _triggerStatus = box.read<bool>(
              hiveKey: AppHiveKeys.cacheForegroundTriggerStatus, value: false);
        });
  }

  /// load background
  Future<void> loadBackground(GPS gps) async {
    await AppHive.accessBox(
        boxName: AppHiveNames.cacheBackground,
        access: (AppHive box) async {
          List<ModelTrackPoint> mapTp(List<String> s) {
            return s.map((e) => ModelTrackPoint.toSharedModel(e)).toList();
          }

          List<GPS> mapGps(List<String> s) {
            return s.map((e) => GPS.toSharedObject(e)).toList();
          }

          recentTrackPoints = mapTp(box.read<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundRecentTrackpoints,
              value: []));

          localTrackPoints = mapTp(box.read<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundRecentLocalTrackpoints,
              value: []));

          address = box.read<String>(
              hiveKey: AppHiveKeys.cacheBackgroundAddress, value: '');

          calcGpsPoints.addAll(mapGps(box.read<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundCalcGpsPoints, value: [])));

          gpsPoints.addAll(mapGps(box.read<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundGpsPoints, value: [])));

          lastGps = GPS.toSharedObject(box.read<String>(
              hiveKey: AppHiveKeys.cacheBackgroundLastGps,
              value: gps.toSharedString()));

          lastStatusChange = GPS.toSharedObject(box.read<String>(
              hiveKey: AppHiveKeys.cacheBackgroundLastStatusChange,
              value: gps.toSharedString()));

          smoothGpsPoints = mapGps(box.read<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundSmoothGpsPoints, value: []));

          _status = TrackingStatus.values.byName(box.read<String>(
              hiveKey: AppHiveKeys.cacheBackgroundStatus,
              value: TrackingStatus.standing.name));
        });
  }

  /// load background
  Future<void> saveBackground(GPS gps) async {
    await AppHive.accessBox(
        boxName: AppHiveNames.cacheBackground,
        access: (AppHive box) async {
          List<String> mapTp(List<ModelTrackPoint> s) {
            return s.map((e) => e.toSharedString()).toList();
          }

          List<String> mapGps(List<GPS> s) {
            return s.map((e) => e.toSharedString()).toList();
          }

          box.write<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundRecentTrackpoints,
              value: mapTp(recentTrackPoints));

          box.write<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundRecentLocalTrackpoints,
              value: mapTp(localTrackPoints));

          box.read<String>(
              hiveKey: AppHiveKeys.cacheBackgroundAddress, value: address);

          box.write<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundCalcGpsPoints,
              value: mapGps(calcGpsPoints));

          box.write<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundGpsPoints,
              value: mapGps(gpsPoints));

          box.write<String>(
              hiveKey: AppHiveKeys.cacheBackgroundLastGps,
              value: lastGps ?? gps.toSharedString());

          box.write<String>(
              hiveKey: AppHiveKeys.cacheBackgroundLastStatusChange,
              value: lastStatusChange ?? gps.toSharedString());

          box.write<List<String>>(
              hiveKey: AppHiveKeys.cacheBackgroundSmoothGpsPoints,
              value: mapGps(smoothGpsPoints));

          box.write<String>(
              hiveKey: AppHiveKeys.cacheBackgroundStatus, value: _status.name);
        });
  }
}

///
///
///
///
///
///
///
enum SharedKeys {
  /// List<String> of key:value pairs
  appSettings,

  /// enum Storages key
  storageKey,

  /// string path of selected storage
  storagePath,

  /// String ModelTrackPoint as sharedString
  /// send from forground to background on status changed
  /// contains userdata to get added to a new trackpoint
  activeTrackPoint,

  /// String address lookup when detected status standing
  /// send from foreground to background
  /// used in Trackpoint::createTrackpoint
  addressStanding,

  /// List<String> of trackpoints to update from foreground to background
  /// updates modified trackpoints from foreground task
  updateTrackPointQueue,

  /// List<String> contains background Logger logs
  workmanagerLogger;
}

enum SharedTypes {
  string,
  list,
  int;
}

class Shared {
  static Logger logger = Logger.logger<Shared>();
  String _observed = '';
  bool _observing = false;
  int _id = 0;
  int get id => ++_id;
  //
  SharedKeys key;
  Shared(this.key);

  String _typeName(SharedTypes type) {
    return '${key.name}_${type.name}';
  }

  static void clear() async {
    (await shared).clear();
  }

  /// prepare module
  static SharedPreferences? _shared;
  static Future<SharedPreferences> get shared async {
    SharedPreferences s = (_shared ?? await SharedPreferences.getInstance());
    _shared = s;
    await s.reload();
    return s;
  }

  Future<List<String>?> loadList() async {
    SharedPreferences sh = await shared;
    List<String> value =
        sh.getStringList(_typeName(SharedTypes.list)) ?? <String>[];
    return value;
  }

  Future<void> saveList(List<String> list) async {
    await (await shared).setStringList(_typeName(SharedTypes.list), list);
  }

  Future<int?> loadInt() async {
    SharedPreferences sh = await shared;
    int? value = sh.getInt(_typeName(SharedTypes.int));
    return value;
  }

  Future<void> saveInt(int i) async {
    await (await shared).setInt(_typeName(SharedTypes.int), i);
  }

  Future<String?> loadString() async {
    SharedPreferences sh = await shared;
    String value = sh.getString(_typeName(SharedTypes.string)) ?? '0\t';
    return value;
  }

  Future<void> saveString(String data) async {
    await (await shared).setString(_typeName(SharedTypes.string), data);
  }

  /// set key to Null
  Future<void> remove() async {
    await (await shared).remove(_typeName(SharedTypes.string));
  }

  /// observes only string types
  void observe(
      {required Duration duration, required Function(String data) fn}) async {
    if (_observing) return;
    _observed = (await loadString()) ?? '';
    Future.delayed(duration, () {
      _observe(duration: duration, fn: fn);
    });
    _observing = true;
  }

  Future<void> _observe(
      {required Duration duration, required Function(String data) fn}) async {
    String obs;
    while (true) {
      if (!_observing) break;
      try {
        obs = (await loadString()) ?? '';
      } catch (e, stk) {
        logger.error('observing failed with $e', stk);
        obs = '';
      }
      if (obs != _observed) {
        _observed = obs;
        try {
          fn(obs);
        } catch (e, stk) {
          logger.error('observing failed with $e', stk);
        }
      }
      await Future.delayed(duration);
    }
  }

  void cancel() {
    logger.log('cancel observing on key ${key.name}');
    _observing = false;
  }
}
