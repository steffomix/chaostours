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

import 'dart:collection';

import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/database.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:sqflite/sqflite.dart';

class ModelTrackPoint {
  static Logger logger = Logger.logger<ModelTrackPoint>();

  final int id;
  final GPS gps;
  bool isActive = true;

  final DateTime timeStart;
  final DateTime timeEnd;

  /// "id,id,..." needs to be sorted by distance
  //List<int> idAlias = [];
  List<ModelAlias> aliasModels = [];

  //List<int> idUser = [];
  List<ModelUser> userModels = [];

  /// "id,id,..." needs to be ordered by user
  //List<int> idTask = [];
  List<ModelTask> taskModels = [];

  ///
  String address = '';
  String notes = '';
  String calendarEventId = ''; // calendarId;calendarEventId

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length

  /// temporary distance for sort
  int sortDistance = 0;

  ModelTrackPoint(
      {required this.id,
      required this.timeStart,
      required this.timeEnd,
      required this.gps,
      this.isActive = true,
      this.address = '',
      this.notes = '',
      this.calendarEventId = ''});

  String timeElapsed() {
    return util.timeElapsed(timeStart, timeEnd);
  }

  static countAlias(int id) async {
    var table = TableTrackPointAlias.table;
    var idAlias = TableTrackPointAlias.idAlias;
    var idTrackPoint = TableTrackPointAlias.idTrackPoint;
    var field = 'count';
    String q = '''
    SELECT COUNT($idAlias) AS $field FROM $table WHERE $idTrackPoint = $id;
''';
    var res = await DB.query((Transaction txn) async {
      List<Map<String, Object?>> res = await txn.query(table,
          columns: ['COUNT($idAlias) AS $field'],
          where: ' $idTrackPoint = ?',
          whereArgs: [id],
          groupBy: idTrackPoint.toString());
      if (res.isEmpty) {
        return 0;
      }
      int count = DB.parseInt(res.first[field]);
      return count;
    });
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableTrackPoint.primaryKey.column: id,
      TableTrackPoint.latitude.column: gps.lat,
      TableTrackPoint.longitude.column: gps.lon,
      TableTrackPoint.timeStart.column: timeStart.toIso8601String(),
      TableTrackPoint.timeEnd.column: timeEnd.toIso8601String(),
      TableTrackPoint.address.column: address
    };
  }

  ///
  /// insert only if Model doesn't have a valid (not null) _id
  /// otherwise writes table to disk
  ///
  static Future<ModelTrackPoint> insert(
      {required GPS gps,
      required DateTime timeStart,
      required DateTime timeEnd}) async {
    Map<String, Object?> params = {
      TableTrackPoint.latitude.column: gps.lat,
      TableTrackPoint.longitude.column: gps.lon,
      TableTrackPoint.timeStart.column: timeStart.toIso8601String(),
      TableTrackPoint.timeEnd.column: timeEnd.toIso8601String()
    };

    int id = await DB.query<int>((Transaction txn) async {
      return await txn.insert(TableTrackPoint.table, params);
    });

    return ModelTrackPoint(
        id: id, gps: gps, timeStart: timeStart, timeEnd: timeEnd);
  }

  ///
  /// Returns true if Model existed
  /// otherwise false and Model will be inserted.
  /// The Model will then have a valid id
  /// that reflects (is same as) Table length.
  ///
  static Future<int> update(ModelTrackPoint m) async {
    return DB.query<int>((Transaction txn) async {
      return await txn.update(TableTrackPoint.table, m.toMap(),
          where: '${TableTrackPoint.primaryKey} = ?', whereArgs: [m.id]);
    });
  }

  ModelTrackPoint clone() {
    var model = ModelTrackPoint(
        id: id, gps: gps, timeStart: timeStart, timeEnd: timeEnd);
    model.address = address;
    return model;
  }

  Future<bool> _addAsset(
      {required String table,
      required String columnTrackPoint,
      required String columnForeign,
      required int idForeign}) async {
    try {
      await DB.query<int>((Transaction txn) async {
        return await txn
            .insert(table, {columnTrackPoint: id, columnForeign: idForeign});
      });
      return true;
    } catch (e) {
      logger.warn('addAlias: $e');
      return false;
    }
  }

  /// ignores dupliate errors but logs a warning
  Future<bool> addAlias(ModelAlias m) async {
    return await _addAsset(
        table: TableTrackPointAlias.table,
        columnTrackPoint: TableTrackPointAlias.idTrackPoint.column,
        columnForeign: TableTrackPointAlias.idAlias.column,
        idForeign: m.id);
  }

  /// ignores dupliate errors but logs a warning
  Future<bool> addTask(ModelTask m) async {
    return await _addAsset(
        table: TableTrackPointTask.table,
        columnTrackPoint: TableTrackPointTask.idTrackPoint.column,
        columnForeign: TableTrackPointTask.idTask.column,
        idForeign: m.id);
  }

  /// ignores dupliate errors but logs a warning
  Future<bool> addUser(ModelUser m) async {
    return await _addAsset(
        table: TableTrackPointUser.table,
        columnTrackPoint: TableTrackPointUser.idTrackPoint.column,
        columnForeign: TableTrackPointUser.idUser.column,
        idForeign: m.id);
  }

  Future<bool> _removeAsset(
      {required String table,
      required String columnTrackPoint,
      required String columnForeign,
      required int idForeign}) async {
    var i = await DB.query<int>((Transaction txn) async {
      return await txn.delete(table,
          where: '$columnTrackPoint = ? AND $columnForeign = ?',
          whereArgs: [id, idForeign]);
    });
    return i > 0;
  }

  /// ignores dupliate errors but logs a warning
  Future<bool> removeAlias(ModelAlias m) async {
    return await _removeAsset(
        table: TableTrackPointAlias.table,
        columnTrackPoint: TableTrackPointAlias.idTrackPoint.column,
        columnForeign: TableTrackPointAlias.idAlias.column,
        idForeign: m.id);
  }

  /// ignores dupliate errors but logs a warning
  Future<bool> removeTask(ModelTask m) async {
    return await _removeAsset(
        table: TableTrackPointTask.table,
        columnTrackPoint: TableTrackPointTask.idTrackPoint.column,
        columnForeign: TableTrackPointTask.idTask.column,
        idForeign: m.id);
  }

  /// ignores dupliate errors but logs a warning
  Future<bool> removeUser(ModelUser m) async {
    return await _removeAsset(
        table: TableTrackPointUser.table,
        columnTrackPoint: TableTrackPointUser.idTrackPoint.column,
        columnForeign: TableTrackPointUser.idUser.column,
        idForeign: m.id);
  }

  Future _getAssetIds(
      {required String table,
      required String columnTrackPoint,
      required String columnForeign}) async {
    return await DB.query<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(table,
          columns: [columnForeign],
          where: '$columnTrackPoint = ?',
          whereArgs: [id]);
    });
  }

  Future<List<ModelAlias>> getAliasList() async {
    final column = TableTrackPointAlias.idAlias.column;
    List<Map<String, Object?>> ids = await _getAssetIds(
        table: TableTrackPointAlias.table,
        columnTrackPoint: TableTrackPointAlias.idTrackPoint.column,
        columnForeign: column);
    if (ids.isNotEmpty) {
      List<int> idList = [];
      for (var row in ids) {
        try {
          idList.add(int.parse(row[column].toString()));
        } catch (e, stk) {
          logger.error('getAlias: $e', stk);
        }
      }
      return await ModelAlias.byIdList(idList);
    }
    return <ModelAlias>[];
  }

  Future<List<ModelTask>> getTaskList() async {
    final column = TableTrackPointTask.idTask.column;
    List<Map<String, Object?>> ids = await _getAssetIds(
        table: TableTrackPointTask.table,
        columnTrackPoint: TableTrackPointTask.idTrackPoint.column,
        columnForeign: column);
    if (ids.isNotEmpty) {
      List<int> idList = [];
      for (var row in ids) {
        try {
          idList.add(int.parse(row[column].toString()));
        } catch (e, stk) {
          logger.error('getTask: $e', stk);
        }
      }
      return await ModelTask.byIdList(idList);
    }
    return <ModelTask>[];
  }

  Future<List<ModelUser>> getUser() async {
    final column = TableTrackPointUser.idUser.column;
    List<int> idList = [];
    List<Map<String, Object?>> ids = await _getAssetIds(
        table: TableTrackPointUser.table,
        columnTrackPoint: TableTrackPointUser.idTrackPoint.column,
        columnForeign: column);
    if (ids.isNotEmpty) {
      for (var row in ids) {
        try {
          idList.add(int.parse(row[column].toString()));
        } catch (e, stk) {
          logger.error('getUser: $e', stk);
        }
      }
    }
    return await ModelUser.byIdList(idList);
  }

  static ModelTrackPoint _fromMap(Map<String, Object?> map) {
    return ModelTrackPoint(
        id: int.parse(map[TableTrackPoint.primaryKey].toString()),
        gps: GPS(double.parse(map[TableTrackPoint.latitude.column].toString()),
            double.parse(map[TableTrackPoint.longitude.column].toString())),
        timeStart:
            DateTime.parse(map[TableTrackPoint.timeStart.column].toString()),
        timeEnd: DateTime.parse(map[TableTrackPoint.timeEnd.column].toString()),
        address: (map[TableTrackPoint.address.column] ?? '').toString(),
        notes: (map[TableTrackPoint.notes.column] ?? '').toString());
  }

  static Future<ModelTrackPoint?> byId(int id) async {
    final rows = await DB.query<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPoint.table,
            where: '${TableTrackPoint.primaryKey} = ?', whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      try {
        _fromMap(rows.first);
      } catch (e, stk) {
        logger.error('byId: $e', stk);
        return null;
      }
    }
    return null;
  }

  static Future<List<ModelTrackPoint>> byIdList(List<int> ids) async {
    final rows = await DB.query<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPoint.table,
            where:
                '${TableTrackPoint.primaryKey} in IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids);
      },
    );
    List<ModelTrackPoint> models = [];
    for (var row in rows) {
      try {
        models.add(_fromMap(row));
      } catch (e, stk) {
        logger.error('byId: $e', stk);
      }
    }
    return models;
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

  static List<ModelTrackPoint> lastVisited(GPS gps) {
    List<ModelTrackPoint> list = [];
    int distance = AppSettings.distanceTreshold;

    for (var tp in _table) {
      tp.sortDistance = GPS.distance(gps, tp.gps).round();
      if (tp.sortDistance <= distance) {
        list.add(tp);
      }
    }
    //list.sort((a, b) => (a.sortDistance - b.sortDistance));
    return list.reversed.toList();
  }

  /// secure method to get models from idLists
  List<ModelTask> getTaskModels() {
    Set<ModelTask> list = {};
    for (int id in idTask) {
      try {
        list.add(ModelTask.getModel(id));
      } catch (e) {
        logger.warn('Task #$id does not exist');
      }
    }
    return list.toList();
  }

  static List<ModelTrackPoint> getAll() {
    return [..._table];
  }

  /// secure method to get models from idLists
  List<ModelUser> getUserModels() {
    Set<ModelUser> list = {};
    for (int id in idTask) {
      try {
        list.add(ModelUser.getModel(id));
      } catch (e) {
        logger.warn('User #$id does not exist');
      }
    }
    return list.toList();
  }

  /// secure method to get models from idLists
  List<ModelAlias> getAliasModels() {
    Set<ModelAlias> list = {};
    for (int id in idTask) {
      try {
        list.add(ModelAlias.getModel(id));
      } catch (e) {
        logger.warn('Alias #$id does not exist');
      }
    }
    return list.toList();
  }

  static bool _searchIdLists(List<int> l1, List<int> l2) {
    var found = false;
    for (var id1 in l1) {
      if (!found) {
        for (var id2 in l2) {
          if (id1 == id2) {
            found = true;
            break;
          }
        }
      }
    }
    return found;
  }

  static List<ModelTrackPoint> search(String search,
      [List<ModelTrackPoint>? resource]) {
    resource ??= ModelTrackPoint.getAll();
    List<ModelTrackPoint> tpList = [];
    if (search.isNotEmpty) {
      List<int> aliasIds = [];
      List<int> userIds = [];
      List<int> taskIds = [];
      for (var model in ModelUser.getAll()) {
        if (model.containsString(search)) {
          userIds.add(model.id);
        }
      }
      for (var model in ModelAlias.getAll()) {
        if (model.containsString(search)) {
          aliasIds.add(model.id);
        }
      }
      for (var model in ModelTask.getAll()) {
        if (model.containsString(search)) {
          taskIds.add(model.id);
        }
      }
      for (var model in resource) {
        if (model.address.contains(search) ||
            model.timeStart.toIso8601String().contains(search) ||
            _searchIdLists(model.idTask, taskIds) ||
            _searchIdLists(model.idUser, userIds) ||
            _searchIdLists(model.idAlias, aliasIds)) {
          tpList.add(model);
        }
      }
      return tpList;
    } else {
      return resource.reversed.toList();
    }
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
    tp.calendarEventId = p[12];
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
    tp.notes = decode(p[11]);
    tp.calendarId = p[12];
    return tp;
  } */

  @override
  String toString() {
    List<String> cols = [
      _id.toString(), // 0
      isActive ? '1' : '0', // 1
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
      calendarEventId,
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
