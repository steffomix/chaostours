import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/file_handler.dart';

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
  List<String> trackPointData = [];
  String activeTrackPoint = '';
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
  /// runs together with background trackPointInterval
  static bool _listening = false;
  void stopListen() => _listening = false;
  bool listen() {
    if (!_listening) {
      _listening = true;
      Future.microtask(() async {
        while (_listening) {
          try {
            logger.log('load background cache');
            await loadBackground();
          } catch (e, stk) {
            logger.error('load background cache: ${e.toString()}', stk);
          }
          try {
            logger.log('save foreground cache');
            await saveForeGround(
                trigger: _triggerStatus,
                trackPoints: trackPointData,
                activeTp: activeTrackPoint);
          } catch (e, stk) {
            logger.error('load foreground cache: ${e.toString()}', stk);
          }
          EventManager.fire<EventOnCacheLoaded>(EventOnCacheLoaded());
          await Future.delayed(Globals.trackPointInterval);
        }
      });
    }
    return _listening;
  }

  Future<void> _save({required String file, required String data}) async {
    String storage = FileHandler.combinePath(
        FileHandler.storages[Storages.appInternal]!, file);
    await FileHandler.write(storage, data);
  }

  Future<String> _load({required String file}) async {
    String storage = FileHandler.combinePath(
        FileHandler.storages[Storages.appInternal]!, file);
    return await FileHandler.read(storage);
  }

  Future<void> saveForeGround(
      {required bool trigger,
      required List<String> trackPoints,
      required String activeTp}) async {
    Map<String, dynamic> jsonObject = {
      JsonKeys.fgTriggerStatus.name: trigger ? '1' : '0',
      JsonKeys.fgTrackPointUpdates.name: trackPoints,
      JsonKeys.fgActiveTrackPoint.name: activeTp
    };
    String jsonString = jsonEncode(jsonObject);
    logger.log('save forground json: $jsonString');
    await _save(file: FileHandler.foregroundCacheFile, data: jsonString);
  }

  Future<void> loadForeGround() async {
    Map<String, dynamic> json = {
      JsonKeys.fgTriggerStatus.name: false,
      JsonKeys.fgTrackPointUpdates.name: <String>[],
      JsonKeys.fgActiveTrackPoint.name: ''
    };
    try {
      String data = await _load(file: FileHandler.foregroundCacheFile);
      json = jsonDecode(data);

      /// trigger status
      try {
        _triggerStatus =
            (json[JsonKeys.fgTriggerStatus.name] ?? '0') == '1' ? true : false;
      } catch (e, stk) {
        logger.error('load trigger status: ${e.toString()}', stk);
      }

      /// update trackPoints
      try {
        trackPointData =
            (json[JsonKeys.fgTrackPointUpdates.name] as List<dynamic>)
                .map((e) => e.toString())
                .toList();
      } catch (e, stk) {
        logger.error('load update trackpoints: ${e.toString()}', stk);
      }

      /// active trackpoint
      try {
        activeTrackPoint = json[JsonKeys.fgActiveTrackPoint.name] ?? '';
      } catch (e, stk) {
        logger.error('load update trackpoints: ${e.toString()}', stk);
      }
    } catch (e, stk) {
      logger.error('loadForeground: ${e.toString()}', stk);
    }
  }

  Future<void> saveBackground(
      {required TrackingStatus status,
      required GPS lastStatus,
      required List<GPS> gpsPoints,
      required List<GPS> smoothGps,
      required GPS lastGps,
      String? address = ''}) async {
    try {
      Map<String, dynamic> jsonObject = {
        JsonKeys.bgStatus.name: status.name,
        JsonKeys.bgLastStatusChange.name: lastStatus.toSharedString(),
        JsonKeys.bgGpsPoints.name:
            gpsPoints.map((e) => e.toSharedString()).toList(),
        JsonKeys.bgCalcGpsPoints.name:
            calcGpsPoints.map((e) => e.toSharedString()).toList(),
        JsonKeys.bgSmoothGpsPoints.name:
            smoothGps.map((e) => e.toSharedString()).toList(),
        JsonKeys.bgLastGps.name: lastGps.toSharedString(),
        JsonKeys.bgAddress.name: address
      };
      String jsonString = jsonEncode(jsonObject);
      logger.log('save json:\n$jsonString');

      await _save(file: FileHandler.backgroundCacheFile, data: jsonString);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }

  Future<void> loadBackground() async {
    Map<String, dynamic> json = {
      JsonKeys.bgStatus.name: TrackingStatus.none.name,
      JsonKeys.bgLastStatusChange.name: null,
      JsonKeys.bgGpsPoints.name: [],
      JsonKeys.bgCalcGpsPoints.name: [],
      JsonKeys.bgSmoothGpsPoints.name: [],
      JsonKeys.bgLastGps.name: '',
      JsonKeys.bgAddress.name: ''
    };

    try {
      String jsonString = await _load(file: FileHandler.backgroundCacheFile);
      logger.log('load json:\n$jsonString');
      json = jsonDecode(jsonString);

      /// status
      try {
        _status = TrackingStatus.values
            .byName(json[JsonKeys.bgStatus.name] ?? _status);
      } catch (e, stk) {
        logger.error(
            'read json status ${json[JsonKeys.bgStatus.name]}: ${e.toString()}',
            stk);
      }

      /// lastStatusChange
      try {
        String lastStatus = json[JsonKeys.bgLastStatusChange.name] ?? '';
        if (lastStatus.isNotEmpty) {
          lastStatusChange = GPS.toSharedObject(lastStatus);
        }
      } catch (e, stk) {
        logger.error(
            'read json lastStatusChange ${json[JsonKeys.bgLastStatusChange.name]}: ${e.toString()}',
            stk);
      }

      /// gpsPoints
      try {
        List<dynamic> points =
            (json[JsonKeys.bgGpsPoints.name] as List<dynamic>);
        for (var p in points) {
          gpsPoints.add(GPS.toSharedObject(p.toString()));
        }
      } catch (e, stk) {
        logger.error(
            'read json gpsPoints ${json[JsonKeys.bgGpsPoints.name]}: ${e.toString()}',
            stk);
      }

      /// smoothGpsPoints
      try {
        List<dynamic> points =
            (json[JsonKeys.bgSmoothGpsPoints.name] as List<dynamic>);
        for (var p in points) {
          smoothGpsPoints.add(GPS.toSharedObject(p.toString()));
        }
      } catch (e, stk) {
        logger.error(
            'read json smoothGps ${json[JsonKeys.bgSmoothGpsPoints.name]}: ${e.toString()}',
            stk);
      }

      /// calcGpsPoints
      try {
        List<dynamic> points =
            (json[JsonKeys.bgCalcGpsPoints.name] as List<dynamic>);
        for (var p in points) {
          calcGpsPoints.add(GPS.toSharedObject(p.toString()));
        }
      } catch (e, stk) {
        logger.error(
            'read json calcGpsPoints ${json[JsonKeys.bgCalcGpsPoints.name]}: ${e.toString()}',
            stk);
      }

      /// last GPS
      try {
        GPS.lastGps =
            lastGps = GPS.toSharedObject(json[JsonKeys.bgLastGps.name]);
      } catch (e, stk) {
        logger.error(
            'read json lastGps ${json[JsonKeys.bgLastGps.name]}: ${e.toString()}',
            stk);
      }

      /// address
      try {
        address = json[JsonKeys.bgAddress.name] ?? ' --- ';
      } catch (e, stk) {
        logger.error(
            'read json address ${json[JsonKeys.bgAddress.name]}: ${e.toString()}',
            stk);
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
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
