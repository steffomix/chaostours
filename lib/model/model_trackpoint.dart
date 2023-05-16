import 'package:chaostours/globals.dart';

import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/background_process/trackpoint.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';

/// required for serialization
/// Todo: move data to Cache and make this class obsolete
class PendingModelTrackPoint extends ModelTrackPoint {
  /// not yet saved active running trackpoint
  static PendingModelTrackPoint pendingTrackPoint = PendingModelTrackPoint(
      gps: GPS(0, 0),
      timeStart: DateTime.now(),
      idAlias: <int>[],
      deleted: false,
      notes: '');

  PendingModelTrackPoint(
      {required super.gps,
      required super.idAlias,
      required super.timeStart,
      super.deleted,
      super.notes});

  /// <p><b>TSV columns: </b></p>
  /// 0 TrackingStatus index<br>
  /// 1 gps.lat<br>
  /// 2 gps.lon<br>
  /// 3 timeStart as toIso8601String<br>
  /// 4 timeEnd as above<br>
  /// 5 idAlias separated by ,<br>
  /// 6 idTask separated by ,<br>
  /// 7 lat, lon TrackPoints separated by ; and reduced to four digits<br>
  /// 8 notes
  /// 9 | as line end
  String toSharedString() {
    List<String> cols = [
      status.index.toString(), // 0
      gps.lat.toString(), // 1
      gps.lon.toString(), // 2
      timeStart.toIso8601String(), // 3
      timeEnd.toIso8601String(), // 4
      idAlias.join(','), // 5
      idTask.join(','), // 6
      idUser.join(','), // 7
      encode(notes), // 8
      '|' // 9 (secure line end)
    ];
    return cols.join('\t');
  }

  /// <p><b>TSV columns: </b></p>
  /// 0 TrackingStatus index<br>
  /// 1 gps.lat <br>
  /// 2 gps.lon<br>
  /// 3 timeStart as toIso8601String<br>
  /// 4 timeEnd as above<br>
  /// 5 idAlias separated by ,<br>
  /// 6 idTask separated by ,<br>
  /// 7 idUser separated by ,<br>
  /// 8 notes
  /// 9 | as line end
  static PendingModelTrackPoint toSharedModel(String row) {
    List<String> p = row.split('\t');
    GPS gps = GPS(double.parse(p[1]), double.parse(p[2]));
    PendingModelTrackPoint model = PendingModelTrackPoint(
        gps: gps,
        timeStart: DateTime.parse(p[3]),
        idAlias: ModelTrackPoint.parseIdList(p[5]),
        deleted: false);
    model.status = TrackingStatus.byValue(int.parse(p[0]));
    model.timeEnd = DateTime.parse(p[4]);
    model.idTask = ModelTrackPoint.parseIdList(p[6]);
    model.idUser = ModelTrackPoint.parseIdList(p[7]);
    model.notes = decode(p[8]);
    return model;
  }
}

class ModelTrackPoint {
  static Logger logger = Logger.logger<ModelTrackPoint>();
  static final List<ModelTrackPoint> _table = [];

  ///
  /// TrackPoint owners
  ///
  TrackingStatus status = TrackingStatus.none;

  ///
  /// Model owners
  ///
  bool deleted = false;
  GPS gps;

  /// "lat,lon;lat,lon;..."
  DateTime timeStart;
  DateTime timeEnd = DateTime.now();

  /// "id,id,..." needs to be sorted by distance
  List<int> idAlias = [];

  List<int> idUser = [];

  /// "id,id,..." needs to be ordered by user
  List<int> idTask = [];
  String notes = '';
  String address = '';

  int _id = 0;

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length
  int get id => _id;

  static int get length => _table.length;

  ModelTrackPoint(
      {required this.gps,
      required this.idAlias,
      required this.timeStart,
      this.deleted = false,
      this.notes = ''});

  static ModelTrackPoint get last => _table.last;

  String timeElapsed() {
    return util.timeElapsed(timeStart, timeEnd);
  }

  static String dump() {
    List<String> dump = [];
    for (var i in _table) {
      dump.add(i.toString());
    }
    return dump.join(Model.lineSep);
  }

  static countAlias(int id) {
    int count = 0;
    for (var item in _table) {
      if (item.idAlias.contains(id)) {
        count++;
      }
    }
    return count;
  }

  ///
  /// insert only if Model doesn't have a valid (not null) _id
  /// otherwise writes table to disk
  ///
  static Future<void> insert(ModelTrackPoint m) async {
    if (m.id <= 0) {
      _table.add(m);
      m._id = _table.length;
      logger.log('Insert TrackPoint #${m._id} "${m.toString()}"');
    } else {
      logger.warn(
          'Insert Trackpoint skipped. TrackPoint with ID ${m._id} already exists');
    }
    await write();
  }

  ///
  /// Returns true if Model existed
  /// otherwise false and Model will be inserted.
  /// The Model will then have a valid id
  /// that reflects (is same as) Table length.
  ///
  static Future<void> update(ModelTrackPoint m) async {
    if (m.id <= 0) {
      logger.warn('Update Trackpoint forwarded to insert '
          'due to negative TrackPoint ID ${m.id}');
      await insert(m);
    } else {
      if (_table.indexWhere((e) => e.id == m.id) >= 0) {
        _table[m.id - 1] = m;
      }
      await write();
    }
  }

  ModelTrackPoint clone() {
    return toModel(toString());
  }

  static Future<void> write() async {
    await Cache.setValue<List<ModelTrackPoint>>(
        CacheKeys.tableModelTrackpoint, _table);
  }

  static Future<int> open() async {
    await Cache.reload();
    _table.clear();
    _table.addAll((await Cache.getValue<List<ModelTrackPoint>>(
        CacheKeys.tableModelTrackpoint, [])));

    return _table.length;
  }

  static Future<void> resetIds() async {
    int id = 1;
    for (var model in _table) {
      model._id = id;
      id++;
    }
    await write();
  }

  void addAlias(ModelAlias m) => idAlias.add(m.id);
  void removeAlias(ModelAlias m) => idAlias.remove(m.id);

  void addTask(ModelTask m) => idTask.add(m.id);
  void removeTask(ModelTask m) => idTask.remove(m.id);

  List<ModelAlias> getAlias() {
    List<ModelAlias> list = [];
    for (int id in idAlias) {
      list.add(ModelAlias.getAlias(id));
    }
    logger.verbose('get ${list.length} alias from TrackPoint ID $id');
    return list;
  }

  static List<ModelTrackPoint> recentTrackPoints({int max = 30}) {
    List<ModelTrackPoint> list = [];
    for (var tp in _table.reversed) {
      list.add(tp);
      if (--max <= 0) {
        break;
      }
    }
    return list.reversed.toList();
  }

  static ModelTrackPoint byId(int id) {
    return _table[id - 1];
  }

  static List<ModelTrackPoint> byAlias(int id) {
    var list = <ModelTrackPoint>[];
    for (var item in _table.reversed) {
      if (item.idAlias.contains(id)) {
        list.add(item);
      }
    }
    return list;
  }

  static List<ModelTrackPoint> lastVisited(GPS gps, {int max = 30}) {
    List<ModelTrackPoint> list = [];
    List<ModelAlias> alias = ModelAlias.nextAlias(gps: gps);
    int distance = Globals.distanceTreshold;
    if (alias.isNotEmpty) {
      gps = GPS(alias.first.lat, alias.first.lon);
      distance = alias.first.radius;
    }
    DateTime time = DateTime.now().subtract(const Duration(days: 365));
    for (var tp in _table.reversed) {
      if (tp.timeStart.isBefore(time)) {
        break;
      }
      if (GPS.distance(gps, tp.gps) <= distance) {
        list.add(tp);
      }
    }
    return list.reversed.toList();
  }

  Set<ModelTask> getTasks() {
    Set<ModelTask> list = {};
    for (int id in idAlias) {
      list.add(ModelTask.getTask(id));
    }
    logger.log('get Tasks: $list');
    return list;
  }

  static T _parse<T>(
      int field, String fieldName, String str, T Function(String s) fn) {
    try {
      return fn(str);
    } catch (e) {
      throw ('Parse error at column ${field + 1} ($fieldName): $e');
    }
  }

  static List<int> _parseList(int field, String fieldName, String str,
      List<int> Function(String s) fn) {
    try {
      return fn(str);
    } catch (e) {
      throw ('Parse error at column ${field + 1} ($fieldName): $e');
    }
  }

  static ModelTrackPoint toModel(String row) {
    List<String> p = row.split('\t');
    if (p.length < 12) {
      throw ('Table Trackpoint must have at least 12 columns: 1:ID, 2:deleted, 3:tracking status, '
          '4:latitude, 5:longitude, 6:time start, 7:time end, 8:alias IDs, 9:task IDs, 10:userIDs, 11:OSM address, 12: notes');
    }
    GPS gps = GPS(_parse<double>(3, 'GPS Latitude', p[3], double.parse),
        _parse<double>(4, 'GPS Longitude', p[4], double.parse));
    //GPS gps = GPS(double.parse(p[3]), double.parse(p[4]));
    ModelTrackPoint tp = ModelTrackPoint(
        deleted: _parse<int>(1, 'Deleted', p[1], int.parse) == 1
            ? true
            : false, //int.parse(p[1]),
        gps: gps,
        timeStart: _parse<DateTime>(
            5, 'Time Start', p[5], DateTime.parse), //DateTime.parse(p[5]),
        idAlias:
            _parseList(7, 'Alias IDs', p[7], parseIdList), // parseIdList(p[7]),
        notes: _parse<String>(11, 'Notes', p[11], decode)); // decode(p[11]));

    tp._id = _parse<int>(0, 'ID', p[0], int.parse); // int.parse(p[0]);
    //tp.status = TrackingStatus.byValue(int.parse(p[2]));

    var type = _parse<int>(2, 'Tracking Status', p[2], int.parse);
    if (type == 1 || type == 2) {
      tp.status = TrackingStatus.byValue(type);
    } else {
      throw ('Tracking Status must be 1 (standing) or 2 (moving)');
    }

    tp.timeEnd = _parse<DateTime>(
        6, 'Time End', p[6], DateTime.parse); //DateTime.parse(p[6]);
    tp.idTask =
        _parseList(8, 'Task IDs', p[8], parseIdList); //parseIdList(p[8]);
    tp.idUser =
        _parseList(9, 'User IDs', p[9], parseIdList); //parseIdList(p[9]);
    tp.address =
        _parse<String>(10, 'OSM Address', p[10], decode); //decode(p[10]);
    return tp;
  }

/* 
  static ModelTrackPoint toModel(String row) {
    List<String> p = row.split('\t');
    GPS gps = GPS(double.parse(p[3]), double.parse(p[4]));
    ModelTrackPoint tp = ModelTrackPoint(
        deleted: int.parse(p[1]),
        gps: gps,
        timeStart: DateTime.parse(p[5]),
        idAlias: parseIdList(p[7]),
        notes: decode(p[11]));

    tp._id = int.parse(p[0]);
    tp.status = TrackingStatus.byValue(int.parse(p[2]));
    tp.timeEnd = DateTime.parse(p[6]);
    tp.idTask = parseIdList(p[8]);
    tp.idUser = parseIdList(p[9]);
    tp.address = decode(p[10]);
    return tp;
  } */

  @override
  String toString() {
    List<String> cols = [
      _id.toString(), // 0
      deleted ? '1' : '0', // 1
      status.index.toString(), // 2
      gps.lat.toString(), // 3
      gps.lon.toString(), // 4
      timeStart.toIso8601String(), // 5
      timeEnd.toIso8601String(), // 6
      idAlias.join(','), // 7
      idTask.join(','), // 8
      idUser.join(','), // 9
      encode(address), // 10
      encode(notes), // 11
      '|'
    ];
    return cols.join('\t');
  }

  //
  static List<GPS> parseGpsList(String string) {
    //return tps;
    List<String> src = string.split(';').where((e) => e.isNotEmpty).toList();
    List<GPS> gpsList = [];
    for (var item in src) {
      List<String> coords = item.split(',');
      gpsList.add(GPS(double.parse(coords[0]), double.parse(coords[1])));
    }
    return gpsList;
  }

  static List<int> parseIdList(String string) {
    string = string.trim();
    Set<int> ids = {}; // make sure they are unique
    if (string.isEmpty) return ids.toList();
    List<String> list = string.split(',');
    for (var item in list) {
      ids.add(int.parse(item));
    }
    return ids.toList();
  }
}
