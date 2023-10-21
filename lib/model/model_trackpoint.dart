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

import 'package:chaostours/calendar.dart';
import 'package:chaostours/database.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:sqflite/sqflite.dart';

class ModelTrackPoint {
  static Logger logger = Logger.logger<ModelTrackPoint>();

  int _id = 0;
  int get id => _id;
  GPS gps;

  DateTime timeStart;
  DateTime timeEnd;

  /// "id,id,..." needs to be sorted by distance
  List<int> aliasIds = [];
  List<ModelAlias> aliasModels = [];

  List<int> userIds = [];
  List<ModelUser> userModels = [];

  /// "id,id,..." needs to be ordered by user
  List<int> taskIds = [];
  List<ModelTask> taskModels = [];

  ///
  String address = '';
  String notes = '';
  List<CalendarEventId> calendarEventIds = []; // calendarId;calendarEventId

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length

  /// temporary distance for sort
  int sortDistance = 0;

  ModelTrackPoint(
      {required this.timeStart,
      required this.timeEnd,
      required this.gps,
      this.address = '',
      this.notes = '',
      this.calendarEventIds = const []});

  String timeElapsed() {
    return util.timeElapsed(timeStart, timeEnd);
  }

  ModelTrackPoint clone() => fromMap(toMap());

  /// creates an empty trackpoint with GPS(0,0)
  static ModelTrackPoint createTrackPoint() {
    var t = DateTime.now();
    return ModelTrackPoint(gps: GPS(0, 0), timeStart: t, timeEnd: t);
  }

  static Future<int> countAlias(int id) async {
    var table = TableTrackPointAlias.table;
    var idTrackPoint = TableTrackPointAlias.idTrackPoint;
    var field = 'ct';
    var res =
        await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(table,
          columns: ['count(*) AS $field'],
          where: ' $idTrackPoint = ?',
          whereArgs: [id]);
    });
    return res.length;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableTrackPoint.primaryKey.column: id,
      TableTrackPoint.latitude.column: gps.lat,
      TableTrackPoint.longitude.column: gps.lon,
      TableTrackPoint.timeStart.column:
          (timeStart.millisecondsSinceEpoch / 1000).round(),
      TableTrackPoint.timeEnd.column:
          (timeEnd.millisecondsSinceEpoch / 1000).round(),
      TableTrackPoint.address.column: address
    };
  }

  static ModelTrackPoint fromMap(Map<String, Object?> map) {
    var model = ModelTrackPoint(
        gps: GPS(DB.parseDouble(map[TableTrackPoint.latitude.column]),
            DB.parseDouble(map[TableTrackPoint.longitude.column])),
        timeStart:
            DB.intToTime(DB.parseInt(map[TableTrackPoint.timeStart.column])),
        timeEnd: DB.intToTime(DB.parseInt(map[TableTrackPoint.timeEnd.column])),
        address: (map[TableTrackPoint.address.column] ?? '').toString(),
        notes: (map[TableTrackPoint.notes.column] ?? '').toString());
    model._id = DB.parseInt(map[TableTrackPoint.primaryKey.column]);
    return model;
  }

  static Future<int> count({ModelAlias? alias}) async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        List<Map<String, Object?>> rows;
        if (alias == null) {
          rows = await txn
              .query(TableTrackPoint.table, columns: ['count(*) as $col']);
        } else {
          rows = await txn.query(TableTrackPointAlias.table,
              columns: ['count(*) as $col'],
              where: "${TableTrackPointAlias.idAlias} = ?",
              whereArgs: [alias.id]);
        }

        if (rows.isNotEmpty) {
          return DB.parseInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  ///
  /// insert only if Model doesn't have a valid (not null) _id
  /// otherwise writes table to disk
  ///
  static Future<ModelTrackPoint> insert(ModelTrackPoint model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableTrackPoint.primaryKey.column);
    await DB.execute<int>((Transaction txn) async {
      int newId = await txn.insert(TableTrackPoint.table, map);
      model._id = newId;
      for (var id in model.aliasIds) {
        try {
          await txn.insert(TableTrackPointAlias.table, {
            TableTrackPointAlias.idAlias.column: id,
            TableTrackPointAlias.idTrackPoint.column: model.id
          });
        } catch (e, stk) {
          logger.error('insert idAlias: $e', stk);
        }
      }
      for (var id in model.taskIds) {
        try {
          await txn.insert(TableTrackPointTask.table, {
            TableTrackPointTask.idTask.column: id,
            TableTrackPointTask.idTrackPoint.column: model.id
          });
        } catch (e, stk) {
          logger.error('insert idTask: $e', stk);
        }
      }
      for (var id in model.userIds) {
        try {
          await txn.insert(TableTrackPointUser.table, {
            TableTrackPointUser.idUser.column: id,
            TableTrackPointUser.idTrackPoint.column: model.id
          });
        } catch (e, stk) {
          logger.error('insert idUser: $e', stk);
        }
      }
      return newId;
    });
    return model;
  }

  ///
  Future<int> update() async {
    if (id <= 0) {
      throw ('update model has no id');
    }
    return await DB.execute<int>((Transaction txn) async {
      return await txn.update(TableTrackPoint.table, toMap(),
          where: '${TableTrackPoint.primaryKey.column} = ?', whereArgs: [id]);
    });
  }

  Future<bool> _addAsset(
      {required String table,
      required String columnTrackPoint,
      required String columnForeign,
      required int idForeign}) async {
    try {
      await DB.execute<int>((Transaction txn) async {
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
    var i = await DB.execute<int>((Transaction txn) async {
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
    return await DB
        .execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(table,
          columns: [columnForeign],
          where: '$columnTrackPoint = ?',
          whereArgs: [id]);
    });
  }

  Future<List<ModelAlias>> loadAliasList() async {
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
      aliasIds = idList;
      aliasModels = await ModelAlias.byIdList(idList);
      return aliasModels;
    }
    return <ModelAlias>[];
  }

  Future<List<ModelTask>> loadTaskList() async {
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
      taskIds = idList;
      taskModels = await ModelTask.byIdList(idList);
      return taskModels;
    }
    return <ModelTask>[];
  }

  Future<List<ModelUser>> loadUserList() async {
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
    userIds = idList;
    userModels = await ModelUser.byIdList(idList);
    return userModels;
  }

  Future<void> loadAssets() async {
    aliasModels = await loadAliasList();
    taskModels = await loadTaskList();
    userModels = await loadUserList();
  }

  static Future<ModelTrackPoint?> byId(int id) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            where: '${TableTrackPoint.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      try {
        var model = fromMap(rows.first);
        model.loadAssets();
        return model;
      } catch (e, stk) {
        logger.error('byId: $e', stk);
        return null;
      }
    }
    return null;
  }

  static Future<List<ModelTrackPoint>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelTrackPoint>[];
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            where:
                '${TableTrackPoint.primaryKey.column} in IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids);
      },
    );
    List<ModelTrackPoint> models = [];
    for (var row in rows) {
      try {
        var model = fromMap(row);
        await model.loadAssets();
        models.add(model);
      } catch (e, stk) {
        logger.error('byId: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelTrackPoint>> select(
      {int offset = 0, int limit = 50}) async {
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            offset: offset,
            limit: limit,
            orderBy: '${TableTrackPoint.timeStart.column} DESC');
      },
    );
    var models = <ModelTrackPoint>[];
    for (var row in rows) {
      try {
        var model = fromMap(row);
        await model.loadAssets();
        models.add(model);
      } catch (e, stk) {
        logger.error('select: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelTrackPoint>> byAlias(ModelAlias alias,
      {int offset = 0, int limit = 50}) async {
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPointAlias.table,
            columns: TableTrackPointAlias.columns,
            where: '${TableTrackPointAlias.idAlias} = ?',
            whereArgs: [alias.id],
            offset: offset,
            limit: limit);
      },
    );
    var ids = <int>[];
    for (var row in rows) {
      try {
        ids.add(DB.parseInt(row[TableTrackPointAlias.idTrackPoint.column]));
      } catch (e, stk) {
        logger.error('byAlias select ids: $e', stk);
      }
    }
    var models = <ModelTrackPoint>[];
    if (ids.isEmpty) {
      return models;
    }
    rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            where:
                '${TableTrackPoint.primaryKey.column} IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids);
      },
    );
    for (var row in rows) {
      try {
        var model = fromMap(row);
        await model.loadAssets();
        models.add(model);
      } catch (e, stk) {
        logger.error('byAlias select models: $e', stk);
      }
    }
    return models;
  }

  ///
  static Future<List<ModelTrackPoint>> lastVisited(
      {required GPS gps, required int radius}) async {
    var area = GpsArea.calculateArea(
        latitude: gps.lat, longitude: gps.lon, distance: radius);
    var table = TableTrackPoint.table;
    var latCol = TableTrackPoint.latitude.column;
    var lonCol = TableTrackPoint.longitude.column;
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(table,
            columns: TableTrackPoint.columns,
            where:
                '$latCol > ? AND $latCol < ? AND $lonCol > ? AND $lonCol < ?',
            whereArgs: [area.latMin, area.latMax, area.lonMin, area.lonMax],
            orderBy: '${TableTrackPoint.timeStart.column} ASC');
      },
    );
    var rawModels = <ModelTrackPoint>[];
    for (var row in rows) {
      rawModels.add(fromMap(row));
    }
    var models = <ModelTrackPoint>[];
    for (var model in rawModels) {
      if (GPS.distance(model.gps, gps) <= radius) {
        await model.loadAssets();
        models.add(model);
      }
    }
    return models;
  }

  static Future<List<ModelTrackPoint>> search(String text) async {
    const idcol = 'id';
    var aliasModels = await ModelAlias.search(text);
    var aliasIdRows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPointAlias.table,
            columns: ['${TableTrackPointAlias.idTrackPoint} as $idcol'],
            where:
                '${TableTrackPointAlias.idAlias.column} IN (${List.filled(aliasModels.length, '?').join(', ')})',
            whereArgs: aliasModels.map((e) => e.id).toList());
      },
    );

    ///
    var taskModels = await ModelTask.search(text);
    var taskIdRows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPointTask.table,
            columns: ['${TableTrackPointTask.idTrackPoint} as $idcol'],
            where:
                '${TableTrackPointTask.idTask.column} IN (${List.filled(taskModels.length, '?').join(', ')})',
            whereArgs: taskModels.map((e) => e.id).toList());
      },
    );

    ///
    var userModels = await ModelUser.search(text);
    var userIdRows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPointUser.table,
            columns: ['${TableTrackPointUser.idTrackPoint} as $idcol'],
            where:
                '${TableTrackPointUser.idUser.column} IN (${List.filled(userModels.length, '?').join(', ')})',
            whereArgs: userModels.map((e) => e.id).toList());
      },
    );

    ///
    Set<int> ids = {};
    for (var row in <Map<String, Object?>>[
      ...aliasIdRows,
      ...taskIdRows,
      ...userIdRows
    ]) {
      ids.add(DB.parseInt(row[idcol]));
    }

    ///
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            where: '${TableTrackPoint.address.column} like ? OR '
                '${TableTrackPoint.primaryKey.column} IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ['%text%', ...ids.toList()]);
      },
    );
    var models = <ModelTrackPoint>[];
    for (var row in rows) {
      var model = fromMap(row);
      await model.loadAssets();
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search at parse models: $e', stk);
      }
    }
    return models;
  }
}
