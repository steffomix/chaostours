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

class ModelTrackPoint extends Model {
  static Logger logger = Logger.logger<ModelTrackPoint>();

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
      {required super.id,
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

  ModelTrackPoint clone() {
    var model = ModelTrackPoint(
        id: id, gps: gps, timeStart: timeStart, timeEnd: timeEnd);
    model.address = address;
    return model;
  }

  static Future<int> countAlias(int id) async {
    var table = TableTrackPointAlias.table;
    var idAlias = TableTrackPointAlias.idAlias;
    var idTrackPoint = TableTrackPointAlias.idTrackPoint;
    var field = 'count';
    var res =
        await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(table,
          columns: ['COUNT(${idAlias.column}) AS $field'],
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

  static ModelTrackPoint _fromMap(Map<String, Object?> map) {
    return ModelTrackPoint(
        id: DB.parseInt(map[TableTrackPoint.primaryKey.column]),
        gps: GPS(DB.parseDouble(map[TableTrackPoint.latitude.column]),
            DB.parseDouble(map[TableTrackPoint.longitude.column])),
        timeStart:
            DB.intToTime(DB.parseInt(map[TableTrackPoint.timeStart.column])),
        timeEnd: DB.intToTime(DB.parseInt(map[TableTrackPoint.timeEnd.column])),
        address: (map[TableTrackPoint.address.column] ?? '').toString(),
        notes: (map[TableTrackPoint.notes.column] ?? '').toString());
  }

  ///
  /// insert only if Model doesn't have a valid (not null) _id
  /// otherwise writes table to disk
  ///
  static Future<ModelTrackPoint> insert(ModelTrackPoint model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableTrackPoint.primaryKey.column);
    int id = await DB.execute<int>((Transaction txn) async {
      return await txn.insert(TableTrackPoint.table, map);
    });
    model.id = id;
    return model;
  }

  ///
  static Future<int> update(ModelTrackPoint model) async {
    if (model.id <= 0) {
      throw ('update model has no id');
    }
    return await DB.execute<int>((Transaction txn) async {
      return await txn.update(TableTrackPoint.table, model.toMap(),
          where: '${TableTrackPoint.primaryKey.column} = ?',
          whereArgs: [model.id]);
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

  Future<List<ModelUser>> getUserList() async {
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
        _fromMap(rows.first);
      } catch (e, stk) {
        logger.error('byId: $e', stk);
        return null;
      }
    }
    return null;
  }

  static Future<List<ModelTrackPoint>> byIdList(List<int> ids) async {
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
        models.add(_fromMap(row));
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
        models.add(_fromMap(row));
      } catch (e, stk) {
        logger.error('select: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelTrackPoint>> byAlias(ModelAlias alias) async {
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPointAlias.table,
            columns: TableTrackPointAlias.columns,
            where: '${TableTrackPointAlias.idAlias} = ?',
            whereArgs: [alias.id]);
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
        models.add(_fromMap(row));
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
      rawModels.add(_fromMap(row));
    }
    var models = <ModelTrackPoint>[];
    for (var model in rawModels) {
      if (GPS.distance(model.gps, gps) <= radius) {
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
                '${TableTrackPointAlias.idAlias.column} IN (${List.filled(aliasModels.length, '?')})',
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
                '${TableTrackPointTask.idTask.column} IN (${List.filled(taskModels.length, '?')})',
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
                '${TableTrackPointUser.idUser.column} IN (${List.filled(userModels.length, '?')})',
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
      try {
        models.add(_fromMap(row));
      } catch (e, stk) {
        logger.error('search at parse models: $e', stk);
      }
    }
    return models;
  }
}
