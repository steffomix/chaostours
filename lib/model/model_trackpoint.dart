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

import 'package:chaostours/model/model_location_group.dart';
import 'package:sqflite/sqflite.dart';

///
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/gps_location.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:chaostours/calendar.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/model/model_location.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint_asset.dart';
import 'package:chaostours/model/model_trackpoint_location.dart';
import 'package:chaostours/model/model_trackpoint_user.dart';
import 'package:chaostours/model/model_trackpoint_task.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';

class ModelTrackPoint {
  static Logger logger = Logger.logger<ModelTrackPoint>();

  int _id = 0;
  int get id => _id;

  bool isActive;
  GPS gps;

  DateTime timeStart;
  DateTime timeEnd;

  ///
  String address = '';
  String fullAddress = '';
  String notes = ''; // calendarId;calendarEventId

  /// "id,id,..." needs to be sorted by distance
  List<ModelTrackpointLocation> locationModels = [];
  List<ModelTrackpointUser> userModels = [];
  List<ModelTrackpointTask> taskModels = [];

  List<CalendarEventId> calendarEventIds = [];

  Duration get duration => timeEnd.difference(timeStart).abs();

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length

  /// temporary distance for sort
  int sortDistance = 0;

  ModelTrackPoint(
      {required this.gps,
      required this.timeStart,
      required this.timeEnd,
      this.isActive = true,
      this.address = '',
      this.fullAddress = '',
      this.notes = '',
      this.calendarEventIds = const []});

  String timeElapsed() {
    return util.formatDuration(timeStart.difference(timeStart).abs());
  }

  ModelTrackPoint clone() => fromMap(toMap());

  static Future<int> countLocation(int id) async {
    var table = TableTrackPointLocation.table;
    var idTrackPoint = TableTrackPointLocation.idTrackPoint;
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
      TableTrackPoint.isActive.column: TypeAdapter.serializeBool(isActive),
      TableTrackPoint.latitude.column: gps.lat,
      TableTrackPoint.longitude.column: gps.lon,
      TableTrackPoint.timeStart.column:
          (timeStart.millisecondsSinceEpoch / 1000).round(),
      TableTrackPoint.timeEnd.column:
          (timeEnd.millisecondsSinceEpoch / 1000).round(),
      TableTrackPoint.address.column: address,
      TableTrackPoint.fullAddress.column: fullAddress,
      TableTrackPoint.notes.column: notes
    };
  }

  static ModelTrackPoint fromMap(Map<String, Object?> map) {
    var model = ModelTrackPoint(
        gps: GPS(
            TypeAdapter.deserializeDouble(map[TableTrackPoint.latitude.column]),
            TypeAdapter.deserializeDouble(
                map[TableTrackPoint.longitude.column])),
        isActive:
            TypeAdapter.deserializeBool(map[TableTrackPoint.isActive.column]),
        timeStart: TypeAdapter.dbIntToTime(
            TypeAdapter.deserializeInt(map[TableTrackPoint.timeStart.column])),
        timeEnd: TypeAdapter.dbIntToTime(
            TypeAdapter.deserializeInt(map[TableTrackPoint.timeEnd.column])),
        address:
            TypeAdapter.deserializeString(map[TableTrackPoint.address.column]),
        fullAddress: TypeAdapter.deserializeString(
            map[TableTrackPoint.fullAddress.column]),
        notes:
            TypeAdapter.deserializeString(map[TableTrackPoint.notes.column]));
    model._id =
        TypeAdapter.deserializeInt(map[TableTrackPoint.primaryKey.column]);
    return model;
  }

  Future<ModelTrackPoint> addSharedAssets(GpsLocation location) async {
    locationModels.clear();
    for (var model in location.locationModels) {
      locationModels.add(
          ModelTrackpointLocation(model: model, trackpointId: 0, notes: ''));
    }

    userModels.clear();
    for (var asset in await Cache.backgroundSharedUserList
        .load<List<SharedTrackpointUser>>([])) {
      var model = await ModelUser.byId(asset.id);
      if (model == null) {
        continue;
      }
      userModels.add(ModelTrackpointUser(
          model: model, trackpointId: 0, notes: asset.notes));
    }

    taskModels.clear();
    for (var asset in await Cache.backgroundSharedTaskList
        .load<List<SharedTrackpointTask>>([])) {
      var model = await ModelTask.byId(asset.id);
      if (model == null) {
        continue;
      }
      taskModels.add(ModelTrackpointTask(
          model: model, trackpointId: 0, notes: asset.notes));
    }
    return this;
  }

  static Future<int> count({ModelLocation? location}) async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        List<Map<String, Object?>> rows;
        if (location == null) {
          rows = await txn
              .query(TableTrackPoint.table, columns: ['count(*) as $col']);
        } else {
          rows = await txn.query(TableTrackPointLocation.table,
              columns: ['count(*) as $col'],
              where: "${TableTrackPointLocation.idLocation} = ?",
              whereArgs: [location.id]);
        }

        if (rows.isNotEmpty) {
          return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
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

      for (var location in locationModels) {
        try {
          addLocation(location, txn);
        } catch (e, stk) {
          logger.error('insert idLocation: $e', stk);
        }
      }
      for (var task in taskModels) {
        try {
          addTask(task, txn);
        } catch (e, stk) {
          logger.error('insert idTask: $e', stk);
        }
      }
      for (var user in userModels) {
        try {
          addUser(user, txn);
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
      required ModelTrackpointAsset asset,
      required Transaction? txn}) async {
    const count = 'ct';

    Future<int> query(Transaction txn) async {
      final rows = await txn.query(table,
          columns: ['COUNT(*) as $count'],
          where: '$columnTrackPoint = ? AND $columnForeign = ?',
          whereArgs: [id, asset.id],
          limit: 1);

      final isUpdate = TypeAdapter.deserializeBool(rows.firstOrNull?[count]);

      return isUpdate
          ? await txn.update(table, {columnNotes: asset.notes},
              where: '$columnTrackPoint = ? AND $columnForeign = ?',
              whereArgs: [id, asset.id])
          : await txn.insert(table, {
              columnTrackPoint: id,
              columnForeign: asset.id,
              columnNotes: asset.notes
            });
    }

    return txn != null
        ? await query(txn)
        : await DB.execute(
            (txn) async {
              return await query(txn);
            },
          );
  }

  Future<int> addLocation(ModelTrackpointLocation asset,
      [Transaction? txn]) async {
    return await _addOrUpdateAsset(
        table: TableTrackPointLocation.table,
        columnTrackPoint: TableTrackPointLocation.idTrackPoint.column,
        columnForeign: TableTrackPointLocation.idLocation.column,
        columnNotes: TableTrackPointLocation.notes.column,
        asset: asset,
        txn: txn);
  }

  Future<int> addTask(ModelTrackpointTask asset, [Transaction? txn]) async {
    return await _addOrUpdateAsset(
        table: TableTrackPointTask.table,
        columnTrackPoint: TableTrackPointTask.idTrackPoint.column,
        columnForeign: TableTrackPointTask.idTask.column,
        columnNotes: TableTrackPointTask.notes.column,
        asset: asset,
        txn: txn);
  }

  Future<int> addUser(ModelTrackpointUser asset, [Transaction? txn]) async {
    return await _addOrUpdateAsset(
        table: TableTrackPointUser.table,
        columnTrackPoint: TableTrackPointUser.idTrackPoint.column,
        columnForeign: TableTrackPointUser.idUser.column,
        columnNotes: TableTrackPointUser.notes.column,
        asset: asset,
        txn: txn);
  }

  Future<int> _removeAsset(
      {required String table,
      required String columnTrackPoint,
      required String columnForeign,
      required ModelTrackpointAsset asset,
      Transaction? txn}) async {
    Future<int> delete(Transaction txn) async {
      return await txn.delete(table,
          where: '$columnTrackPoint = ? AND $columnForeign = ?',
          whereArgs: [id, asset.id]);
    }

    return txn != null
        ? await delete(txn)
        : await DB.execute(
            (txn) async => await delete(txn),
          );
  }

  Future<int> removeLocation(ModelTrackpointLocation asset,
      [Transaction? txn]) async {
    return await _removeAsset(
        table: TableTrackPointLocation.table,
        columnTrackPoint: TableTrackPointLocation.idTrackPoint.column,
        columnForeign: TableTrackPointLocation.idLocation.column,
        asset: asset,
        txn: txn);
  }

  Future<int> removeTask(ModelTrackpointTask asset, [Transaction? txn]) async {
    return await _removeAsset(
        table: TableTrackPointTask.table,
        columnTrackPoint: TableTrackPointTask.idTrackPoint.column,
        columnForeign: TableTrackPointTask.idTask.column,
        asset: asset,
        txn: txn);
  }

  Future<int> removeUser(ModelTrackpointUser asset, [Transaction? txn]) async {
    return await _removeAsset(
        table: TableTrackPointUser.table,
        columnTrackPoint: TableTrackPointUser.idTrackPoint.column,
        columnForeign: TableTrackPointUser.idUser.column,
        asset: asset,
        txn: txn);
  }

  Future<List<ModelTrackpointLocation>> loadLocationList(
      {Transaction? txn, List<int>? ids}) async {
    ids ??= [id];
    const notes = 'trackpoint_notes';
    final q =
        '''SELECT ${TableTrackPointLocation.notes} as $notes, ${TableLocation.columns.join(',')} 
    FROM ${TableTrackPoint.table}
    INNER JOIN ${TableTrackPointLocation.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}
    INNER JOIN ${TableLocation.table} ON ${TableTrackPointLocation.idLocation} = ${TableLocation.id}
    WHERE ${TableTrackPoint.id} IN (${List.filled(ids.length, '?').join(', ')})
''';

    final rows = txn != null
        ? await txn.rawQuery(q, ids)
        : await DB.execute(
            (txn) async {
              return await txn.rawQuery(q, ids);
            },
          );

    List<ModelTrackpointLocation> models = [];
    for (var row in rows) {
      var model = ModelLocation.fromMap(row);
      models.add(ModelTrackpointLocation(
          model: model,
          trackpointId: id,
          notes: TypeAdapter.deserializeString(row[notes])));
    }

    return models;
  }

  Future<List<ModelTrackpointTask>> loadTaskList(
      {Transaction? txn, List<int>? ids}) async {
    ids ??= [id];
    const notes = 'trackpoint_notes';
    final q =
        '''SELECT ${TableTrackPointTask.notes} as $notes, ${TableTask.columns.join(',')} 
    FROM ${TableTrackPoint.table}
    INNER JOIN ${TableTrackPointTask.table} ON ${TableTrackPoint.id} = ${TableTrackPointTask.idTrackPoint}
    INNER JOIN ${TableTask.table} ON ${TableTrackPointTask.idTask} = ${TableTask.id}
    WHERE ${TableTrackPoint.id} IN (${List.filled(ids.length, '?').join(', ')})
''';

    final rows = txn != null
        ? await txn.rawQuery(q, ids)
        : await DB.execute(
            (txn) async {
              return await txn.rawQuery(q, ids);
            },
          );

    List<ModelTrackpointTask> models = [];
    for (var row in rows) {
      var model = ModelTask.fromMap(row);
      models.add(ModelTrackpointTask(
        model: model,
        trackpointId: id,
        notes: TypeAdapter.deserializeString(row[notes]),
      ));
    }

    return models;
  }

  Future<List<ModelTrackpointUser>> loadUserList(
      {Transaction? txn, List<int>? ids}) async {
    ids ??= [id];
    const notes = 'trackpoint_notes';
    final q =
        '''SELECT ${TableTrackPointUser.notes} as $notes, ${TableUser.columns.join(',')} 
    FROM ${TableTrackPoint.table}
    INNER JOIN ${TableTrackPointUser.table} ON ${TableTrackPointUser.idTrackPoint} = ${TableTrackPoint.id}
    INNER JOIN ${TableUser.table} ON  ${TableUser.id} = ${TableTrackPointUser.idUser}
    WHERE ${TableTrackPoint.id} IN (${List.filled(ids.length, '?').join(', ')})
''';

    final rows = txn != null
        ? await txn.rawQuery(q, ids)
        : await DB.execute(
            (txn) async {
              return await txn.rawQuery(q, ids);
            },
          );

    List<ModelTrackpointUser> models = [];
    for (var row in rows) {
      var model = ModelUser.fromMap(row);
      models.add(ModelTrackpointUser(
        model: model,
        trackpointId: id,
        notes: TypeAdapter.deserializeString(row[notes]),
      ));
    }

    return models;
  }

  Future<ModelTrackPoint> loadAssets(Transaction? txn) async {
    locationModels = await loadLocationList(txn: txn);
    taskModels = await loadTaskList(txn: txn);
    userModels = await loadUserList(txn: txn);
    return this;
  }

  static Future<ModelTrackPoint?> byId(int id) async {
    return await DB.execute(
      (Transaction txn) async {
        var rows = await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            where: '${TableTrackPoint.primaryKey.column} = ?',
            whereArgs: [id]);

        if (rows.isNotEmpty) {
          return fromMap(rows.first).loadAssets(txn);
        }
        return null;
      },
    );
  }

  static Future<List<ModelTrackPoint>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelTrackPoint>[];
    }
    return await DB.execute(
      (Transaction txn) async {
        final rows = await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            where:
                '${TableTrackPoint.primaryKey.column} IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids);

        List<ModelTrackPoint> models = [];
        for (var row in rows) {
          try {
            var model = await fromMap(row).loadAssets(txn);
            models.add(model);
          } catch (e, stk) {
            logger.error('byId: $e', stk);
          }
        }
        return models;
      },
    );
  }

  static Future<List<ModelTrackPoint>> select(
      {int offset = 0, int limit = 50}) async {
    return await DB.execute(
      (Transaction txn) async {
        final rows = await txn.query(TableTrackPoint.table,
            columns: TableTrackPoint.columns,
            offset: offset,
            limit: limit,
            orderBy: '${TableTrackPoint.timeStart.column} DESC');

        var models = <ModelTrackPoint>[];
        for (var row in rows) {
          models.add(await fromMap(row).loadAssets(txn));
        }
        return models;
      },
    );
  }

  Future<List<ModelLocationGroup>> locationGroups() async {
    final sql =
        '''SELECT ${TableLocationGroup.columns.join(', ')} FROM ${TableTrackPointLocation.table}
    INNER JOIN ${TableLocationLocationGroup.table} ON ${TableLocationLocationGroup.idLocation} = ${TableTrackPointLocation.idLocation}
    INNER JOIN ${TableLocationGroup.table} ON ${TableLocationGroup.id} = ${TableLocationLocationGroup.idLocationGroup}
    WHERE ${TableTrackPointLocation.idTrackPoint} = ?
    GROUP BY ${TableLocationGroup.id}
''';

    final rows = await DB.execute(
      (txn) async {
        return await txn.rawQuery(sql, [id]);
      },
    );

    return rows.map((e) => ModelLocationGroup.fromMap(e)).toList();
  }

  static Future<List<ModelTrackPoint>> byLocation(ModelLocation location,
      {int offset = 0, int limit = 50}) async {
    return await DB.execute(
      (Transaction txn) async {
        final q =
            '''SELECT ${TableTrackPoint.columns.join(', ')} FROM ${TableTrackPointLocation.table}
        LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}
        WHERE ${TableTrackPointLocation.idLocation} = ?
        LIMIT ?
        OFFSET ?
''';

        var rows = await txn.rawQuery(q, [location.id, limit, offset]);
        List<ModelTrackPoint> models = [];
        for (var row in rows) {
          models.add(await fromMap(row).loadAssets(txn));
        }
        return models;
      },
    );
  }

  ///
  static Future<List<ModelTrackPoint>> lastVisited(
      {required GPS gps, required int radius}) async {
    var area = GpsArea(
        latitude: gps.lat, longitude: gps.lon, distanceInMeters: radius);
    var table = TableTrackPoint.table;
    var latCol = TableTrackPoint.latitude.column;
    var lonCol = TableTrackPoint.longitude.column;
    return await DB.execute(
      (Transaction txn) async {
        final rows = await txn.query(table,
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
        final models = <ModelTrackPoint>[];
        for (var row in rows) {
          var model = fromMap(row);
          if (GPS.distance(model.gps, gps) <= radius) {
            models.add(await model.loadAssets(txn));
          }
        }
        return models;
      },
    );
  }

  static Future<List<ModelTrackPoint>> search(String search,
      {int limit = 20,
      int offset = 0,
      bool isActive = true,
      int? idLocation,
      int? idUser,
      int? idTask,
      int? idLocationGroup,
      int? idUserGroup,
      int? idTaskGroup}) async {
    String? whereTable;
    int? whereId;
    String groupJoin = '';
    if (idLocation != null) {
      whereTable = TableLocation.id.toString();
      whereId = idLocation;
    } else if (idUser != null) {
      whereTable = TableUser.id.toString();
      whereId = idUser;
    } else if (idTask != null) {
      whereTable = TableTask.id.toString();
      whereId = idTask;
    } else if (idLocationGroup != null) {
      groupJoin =
          'INNER JOIN ${TableLocationLocationGroup.table} ON ${TableTrackPointLocation.idLocation} = ${TableLocationLocationGroup.idLocation}';
      whereTable = TableLocationLocationGroup.idLocationGroup.toString();
      whereId = idLocationGroup;
    } else if (idUserGroup != null) {
      groupJoin =
          'INNER JOIN ${TableUserUserGroup.table} ON ${TableTrackPointUser.idUser} = ${TableUserUserGroup.idUser}';
      whereTable = TableUserUserGroup.idUserGroup.toString();
      whereId = idUserGroup;
    } else if (idTaskGroup != null) {
      groupJoin =
          'INNER JOIN ${TableTaskTaskGroup.table} ON ${TableTrackPointTask.idTask} = ${TableTaskTaskGroup.idTask}';
      whereTable = TableTaskTaskGroup.idTaskGroup.toString();
      whereId = idTaskGroup;
    }
    String sqlSearch =
        'WHERE ${TableTrackPoint.isActive} = ? ${whereTable == null ? '' : 'AND $whereTable == ? '} ';
    if (search.isNotEmpty) {
      sqlSearch = '''
        $sqlSearch
        -- where notes
        AND ( ${TableTrackPoint.notes} LIKE ?
        -- where osm address
        OR ${TableTrackPoint.address} LIKE ?
        -- where location
        OR ${TableLocation.title} LIKE ? OR  ${TableLocation.description} LIKE ?
        -- where users
        OR ${TableUser.title} LIKE ? OR ${TableUser.description} LIKE ?
        -- where tasks
        OR ${TableTask.title} LIKE ? OR ${TableTask.description} LIKE ?
        -- where user notes
        OR ${TableTrackPointUser.notes} LIKE ?
        -- where task notes
        OR ${TableTrackPointTask.notes} LIKE ? )
''';
    }

    String sql = '''
        SELECT 
          ${TableTrackPoint.columns.join(', ')}
        FROM ${TableTrackPoint.table}
        -- join location
        LEFT JOIN ${TableTrackPointLocation.table} ON ${TableTrackPointLocation.idTrackPoint} = ${TableTrackPoint.id}
        LEFT JOIN ${TableLocation.table} ON ${TableLocation.id} = ${TableTrackPointLocation.idLocation}
        -- join users
        LEFT JOIN ${TableTrackPointUser.table} ON ${TableTrackPointUser.idTrackPoint} = ${TableTrackPoint.id}
        LEFT JOIN ${TableUser.table} ON ${TableUser.id} = ${TableTrackPointUser.idUser}
        -- join tasks
        LEFT JOIN ${TableTrackPointTask.table} ON ${TableTrackPointTask.idTrackPoint} = ${TableTrackPoint.id}
        LEFT JOIN ${TableTask.table} ON ${TableTask.id} = ${TableTrackPointTask.idTask}
        $groupJoin
        $sqlSearch
        -- query
        GROUP BY ${TableTrackPoint.id}
        ORDER BY ${TableTrackPoint.id} DESC
        LIMIT ?
        OFFSET ?
''';
    var rx = RegExp(r'\?', multiLine: true);
    int qmCount = rx.allMatches(sql).length - 3; // exclute limit and offset

    return await DB.execute((Transaction txn) async {
      final rows = await txn.rawQuery(sql, [
        TypeAdapter.serializeBool(isActive),
        ...(whereTable == null ? [] : [whereId]),
        ...List.filled(qmCount - (whereTable == null ? 0 : 1), '%$search%'),
        limit,
        offset,
      ]);

      List<ModelTrackPoint> trackpoints = [];

      for (var row in rows) {
        trackpoints.add(await fromMap(row).loadAssets(txn));
      }

      return trackpoints;
    });
  }
}
