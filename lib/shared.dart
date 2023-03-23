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
  status,
  lastGps,
  gpsPoints,
  address;
}

class SharedLoader {
  static Logger logger = Logger.logger<SharedLoader>();
  factory SharedLoader() => _instance ??= SharedLoader._();
  static SharedLoader? _instance;
  static SharedLoader get instance => _instance ??= SharedLoader._();
  static int nextId = 0;
  int id = (nextId++);

  // gps list from between trackpoints
  List<GPS> gpsPoints = [];
  // list of all TrackPoints since app is running
  // limit to max 10k
  List<GPS> gpsHistory = [];
  // ignore: prefer_final_fields
  TrackingStatus _status = TrackingStatus.none;
  TrackingStatus get status => _status;

  String address = '';
  List<ModelTrackPoint> recentTrackPoints = [];
  List<ModelTrackPoint> localTrackPoints = [];

  SharedLoader._() {
    EventManager.listen<EventOnAppTick>(_onTick);
  }

  _onTick(EventOnAppTick tick) {
    loadBackground();
  }

  Future<void> saveBackground(
      {required TrackingStatus status,
      required List<GPS> gpsPoints,
      required GPS lastGps,
      String? address = ''}) async {
    Map<String, dynamic> jsonObject = {
      JsonKeys.status.name: status.name,
      JsonKeys.gpsPoints.name: gpsPoints.map((e) => e.toSharedString()),
      JsonKeys.lastGps.name: lastGps.toSharedString(),
      JsonKeys.address.name: ''
    };
    String jsonString = jsonEncode(jsonObject);
    logger.log('save json:\n$jsonString');

    String storage = FileHandler.combinePath(
        FileHandler.storages[Storages.appInternal]!, FileHandler.sharedFile);
    await FileHandler.write(storage, jsonString);
  }

  Future<void> loadBackground() async {
    Map<String, dynamic> json = {
      JsonKeys.status.name: TrackingStatus.none.name,
      JsonKeys.gpsPoints.name: [],
      JsonKeys.lastGps.name: '',
      JsonKeys.address.name: ''
    };

    try {
      String storage = FileHandler.combinePath(
          FileHandler.storages[Storages.appInternal]!, FileHandler.sharedFile);
      String jsonString = await FileHandler.read(storage);
      logger.log('load json:\n$jsonString');
      json = jsonDecode(jsonString);

      /// status
      try {
        _status = TrackingStatus.values
            .byName(json[JsonKeys.status.name] ?? _status.name);
      } catch (e, stk) {
        logger.error('read json ${JsonKeys.status}: ${e.toString()}', stk);
      }

      /// gpsPoints
      try {
        gpsPoints = (json[JsonKeys.gpsPoints.name] as List<String>)
            .map((e) => GPS.toSharedObject(e))
            .toList();
      } catch (e, stk) {
        logger.error('read json ${JsonKeys.status}: ${e.toString()}', stk);
      }

      /// last GPS
      try {
        GPS.lastGps = GPS.toSharedObject(json[JsonKeys.lastGps.name]);
        gpsHistory.add(GPS.lastGps!);
      } catch (e, stk) {
        logger.error('read json ${JsonKeys.status}: ${e.toString()}', stk);
      }

      /// address
      try {
        address = json[JsonKeys.address.name] ?? ' --- ';
      } catch (e, stk) {
        logger.error('read json ${JsonKeys.status}: ${e.toString()}', stk);
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }
}

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
