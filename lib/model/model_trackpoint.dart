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

import 'package:chaostours/database/cache.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_asset.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
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

  ///
  String address = '';
  String notes = ''; // calendarId;calendarEventId

  /// "id,id,..." needs to be sorted by distance
  List<int> get aliasIds => aliasModels
      .map(
        (e) => e.id,
      )
      .toList();
  List<ModelAlias> aliasModels = [];

  List<int> get userIds => userModels
      .map(
        (e) => e.id,
      )
      .toList();
  List<ModelUser> userModels = [];

  /// "id,id,..." needs to be ordered by user
  List<int> get taskIds => taskModels
      .map(
        (e) => e.id,
      )
      .toList();
  List<ModelTask> taskModels = [];

  List<CalendarEventId> calendarEventIds = [];

  Duration get duration => timeEnd.difference(timeStart).abs();

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
    return util.formatDuration(timeStart.difference(timeStart).abs());
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

  Future<ModelTrackPoint> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableTrackPoint.primaryKey.column);
    await DB.execute((Transaction txn) async {
      _id = await txn.insert(TableTrackPoint.table, map);
    });

    final sharedAlias = await Cache.backgroundSharedAliasList
        .load<List<SharedTrackpointAlias>>([]);
    final sharedTasks = await Cache.backgroundSharedTaskList
        .load<List<SharedTrackpointTask>>([]);
    final sharedUsers = await Cache.backgroundSharedUserList
        .load<List<SharedTrackpointUser>>([]);
    await DB.execute((Transaction txn) async {
      for (var alias in sharedAlias) {
        try {
          addAlias(alias, txn);
        } catch (e, stk) {
          logger.error('insert idAlias: $e', stk);
        }
      }
      for (var task in sharedTasks) {
        try {
          addTask(task, txn);
        } catch (e, stk) {
          logger.error('insert idTask: $e', stk);
        }
      }
      for (var user in sharedUsers) {
        try {
          addUser(user, txn);
        } catch (e, stk) {
          logger.error('insert idUser: $e', stk);
        }
      }
      for (var cal in calendarEventIds) {
        try {
          await txn.insert(TableTrackPointCalendar.table, {
            TableTrackPointCalendar.idTrackPoint.column: _id,
            TableTrackPointCalendar.idEvent.column: cal.eventId,
            TableTrackPointCalendar.idCalendar.column: cal.calendarId
          });
        } catch (e, stk) {
          logger.error('insert idUser: $e', stk);
        }
      }
    });
    return this;
  }

  Future<int> update() async {
    if (id <= 0) {
      throw ('update model has no id');
    }
    return await DB.execute<int>((Transaction txn) async {
      return await txn.update(TableTrackPoint.table, toMap(),
          where: '${TableTrackPoint.primaryKey.column} = ?', whereArgs: [id]);
    });
  }

  Future<int> _addOrUpdateAsset(
      {required String table,
      required String columnTrackPoint,
      required String columnForeign,
      required String columnNotes,
      required SharedTrackpointAsset shared,
      required Transaction txn}) async {
    try {
      final rows = await txn.query(table,
          columns: ['COUNT(*) as ct'],
          where: '$columnTrackPoint = ? AND $columnForeign = ?',
          whereArgs: [id, shared.id],
          limit: 1);

      final bool insert = rows.isEmpty;

      return insert
          ? await txn.insert(table, {
              columnTrackPoint: id,
              columnForeign: shared.id,
              columnNotes: shared.notes
            })
          : await txn.update(table, {columnNotes: shared.notes},
              where: '$columnTrackPoint = ? AND $columnForeign = ?',
              whereArgs: [id, shared.id]);
    } catch (e) {
      logger.warn('addAlias: $e');
      return 0;
    }
  }

  Future<int> addAlias(SharedTrackpointAlias shared, Transaction txn) async {
    return await _addOrUpdateAsset(
        table: TableTrackPointAlias.table,
        columnTrackPoint: TableTrackPointAlias.idTrackPoint.column,
        columnForeign: TableTrackPointAlias.idAlias.column,
        columnNotes: TableTrackPointAlias.notes.column,
        shared: shared,
        txn: txn);
  }

  Future<int> addTask(SharedTrackpointTask shared, Transaction txn) async {
    return await _addOrUpdateAsset(
        table: TableTrackPointTask.table,
        columnTrackPoint: TableTrackPointTask.idTrackPoint.column,
        columnForeign: TableTrackPointTask.idTask.column,
        columnNotes: TableTrackPointTask.notes.column,
        shared: shared,
        txn: txn);
  }

  Future<int> addUser(SharedTrackpointUser shared, Transaction txn) async {
    return await _addOrUpdateAsset(
        table: TableTrackPointUser.table,
        columnTrackPoint: TableTrackPointUser.idTrackPoint.column,
        columnForeign: TableTrackPointUser.idUser.column,
        columnNotes: TableTrackPointUser.notes.column,
        shared: shared,
        txn: txn);
  }

  Future<int> _removeAsset(
      {required String table,
      required String columnTrackPoint,
      required String columnForeign,
      required SharedTrackpointAsset shared,
      required Transaction txn}) async {
    return await txn.delete(table,
        where: '$columnTrackPoint = ? AND $columnForeign = ?',
        whereArgs: [id, shared.id]);
  }

  Future<int> removeAlias(SharedTrackpointAlias shared, Transaction txn) async {
    return await _removeAsset(
        table: TableTrackPointAlias.table,
        columnTrackPoint: TableTrackPointAlias.idTrackPoint.column,
        columnForeign: TableTrackPointAlias.idAlias.column,
        shared: shared,
        txn: txn);
  }

  Future<int> removeTask(SharedTrackpointTask shared, Transaction txn) async {
    return await _removeAsset(
        table: TableTrackPointTask.table,
        columnTrackPoint: TableTrackPointTask.idTrackPoint.column,
        columnForeign: TableTrackPointTask.idTask.column,
        shared: shared,
        txn: txn);
  }

  Future<int> removeUser(SharedTrackpointUser shared, Transaction txn) async {
    return await _removeAsset(
        table: TableTrackPointUser.table,
        columnTrackPoint: TableTrackPointUser.idTrackPoint.column,
        columnForeign: TableTrackPointUser.idUser.column,
        shared: shared,
        txn: txn);
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
                '${TableTrackPoint.primaryKey.column} IN (${List.filled(ids.length, '?').join(',')})',
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
            orderBy: TableTrackPoint.timeStart.column);
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
    var area = GpsArea(
        latitude: gps.lat, longitude: gps.lon, distanceInMeters: radius);
    var table = TableTrackPoint.table;
    var latCol = TableTrackPoint.latitude.column;
    var lonCol = TableTrackPoint.longitude.column;
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(table,
            columns: TableTrackPoint.columns,
            where:
                '$latCol > ? AND $latCol < ? AND $lonCol > ? AND $lonCol < ?',
            whereArgs: [
              area.southLatitudeBorder,
              area.northLatitudeBorder,
              area.westLongitudeBorder,
              area.eastLongitudeBorder
            ],
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

  static Future<List<ModelTrackPoint>> search(String search) async {
    const idcol = 'id';
    var aliasModels = await ModelAlias.select(search: search, limit: 50);
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
    var taskModels = await ModelTask.select(search: search, limit: 50);
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
    var userModels = await ModelUser.select(search: search, limit: 50);
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
            whereArgs: ['%$search%', ...ids],
            orderBy: '${TableTrackPoint.timeStart.column} DESC');
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
