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

import 'dart:math';
import 'package:chaostours/conf/app_settings.dart';

///
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/database.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:sqflite/sqflite.dart';

enum AliasVisibility {
  public(1),
  privat(2),
  restricted(3);

  final int value;
  const AliasVisibility(this.value);

  static AliasVisibility byId(Object? value) {
    int id = DB.parseInt(value, fallback: 3);
    id = max(1, min(3, id));
    return byValue(id);
  }

  static AliasVisibility byValue(int id) {
    AliasVisibility status =
        AliasVisibility.values.firstWhere((status) => status.value == id);
    return status;
  }
}

class ModelAlias extends Model {
  static Logger logger = Logger.logger<ModelAlias>();
  int groupId = 1;
  // lazy loaded group
  Future<ModelAliasGroup?> get groupModel => ModelAliasGroup.byId(groupId);
  GPS gps;
  int radius = 50;
  DateTime lastVisited;
  int timesVisited = 0;
  String calendarId = '';
  String title = '';
  String description = '';

  /// group values
  AliasVisibility visibility = AliasVisibility.restricted;
  bool isActive = false;

  /// temporary set during search for nearest Alias
  int sortDistance = 0;
  int trackPointCount = 0;

  ModelAlias({
    super.id = 0,
    this.groupId = 1,
    required this.gps,
    this.radius = 50,
    required this.lastVisited,
    this.timesVisited = 0,
    required this.title,
    this.description = '',
  });

  static ModelAlias fromMap(Map<String, Object?> map) {
    return ModelAlias(
        id: DB.parseInt(map[TableAlias.primaryKey.column]),
        groupId: DB.parseInt(map[TableAlias.idAliasGroup.column], fallback: 1),
        gps: GPS(DB.parseDouble(map[TableAlias.latitude.column]),
            DB.parseDouble(map[TableAlias.longitude.column])),
        radius: DB.parseInt(map[TableAlias.radius.column], fallback: 10),
        lastVisited: DB.intToTime(map[TableAlias.lastVisited.column]),
        timesVisited: DB.parseInt(map[TableAlias.timesVisited.column]),
        title: DB.parseString(map[TableAlias.title.column]),
        description: DB.parseString(map[TableAlias.description.column]));
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableAlias.primaryKey.column: id,
      TableAlias.idAliasGroup.column: groupId,
      TableAlias.latitude.column: gps.lat,
      TableAlias.longitude.column: gps.lon,
      TableAlias.radius.column: radius,
      TableAlias.lastVisited.column: DB.timeToInt(lastVisited),
      TableAlias.timesVisited.column: timesVisited,
      TableAlias.title.column: title,
      TableAlias.description.column: description
    };
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'count';
        var rows = await txn.query(TableAlias.table,
            columns: ['count(${TableAlias.primaryKey.column}) as $col'],
            groupBy: TableAlias.primaryKey.column);

        if (rows.isNotEmpty) {
          return DB.parseInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  Future<int> countTrackPoints() async {
    const col = 'ct';
    var rows = await DB.execute(
      (Transaction txn) async {
        return await txn.query(TableTrackPointAlias.table,
            columns: ['count(${TableTrackPointAlias.idAlias.column}) as $col'],
            where: '${TableTrackPointAlias.idAlias.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return DB.parseInt(rows.first[col]);
    }
    return 0;
  }

  ///
  static Future<ModelAlias?> byId(int id) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableAlias.table,
            columns: TableAlias.columns,
            where: '${TableAlias.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      try {
        fromMap(rows.first);
      } catch (e, stk) {
        logger.error('byId: $e', stk);
        return null;
      }
    }
    return null;
  }

  ///
  static Future<List<ModelAlias>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelAlias>[];
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableAlias.table,
            columns: TableAlias.columns,
            where:
                '${TableAlias.primaryKey.column} in IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids);
      },
    );
    List<ModelAlias> models = [];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('byId: $e', stk);
      }
    }
    return models;
  }

  /// transforms text into %text%
  static Future<List<ModelAlias>> search(String text) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableAlias.table,
            columns: TableAlias.columns,
            where:
                '${TableAlias.title} like ? OR ${TableAlias.description} like ?',
            whereArgs: [text, text]);
      },
    );
    var models = <ModelAlias>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  /// find trackpoints by aliasId
  Future<List<ModelTrackPoint>> trackpoints() async {
    const idCol = 'id';
    var rows =
        await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(TableTrackPointAlias.table,
          columns: ['${TableTrackPointAlias.idTrackPoint.column} as $idCol'],
          where: '${TableTrackPointAlias.idAlias.column} = ?',
          whereArgs: [id]);
    });
    List<int> ids = [];
    for (var row in rows) {
      try {
        ids.add(int.parse(row[idCol].toString()));
      } catch (e, stk) {
        logger.error('visited parse ids: $e', stk);
      }
    }
    return await ModelTrackPoint.byIdList(ids);
  }

  ///
  static Future<List<ModelAlias>> byRadius(
      {required GPS gps, required int radius}) async {
    var area = GpsArea.calculateArea(
        latitude: gps.lat, longitude: gps.lon, distance: radius);
    var table = TableAlias.table;
    var latCol = TableAlias.latitude.column;
    var lonCol = TableAlias.longitude.column;
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(table,
            columns: TableAlias.columns,
            where:
                '$latCol > ? AND $latCol < ? AND $lonCol > ? AND $lonCol < ?',
            whereArgs: [area.latMin, area.latMax, area.lonMin, area.lonMax]);
      },
    );
    var rawModels = <ModelAlias>[];
    for (var row in rows) {
      rawModels.add(fromMap(row));
    }
    var models = <ModelAlias>[];
    for (var model in rawModels) {
      if (GPS.distance(model.gps, gps) <= radius) {
        models.add(model);
      }
    }
    return models;
  }

  static Future<List<ModelAlias>> select(
      {int offset = 0, int limit = 50}) async {
    var rows =
        await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(TableAlias.table,
          columns: TableAlias.columns, offset: offset, limit: limit);
    });
    var models = <ModelAlias>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('select: $e', stk);
      }
    }
    return models;
  }

  static Future<ModelAlias> insert(ModelAlias model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableAlias.primaryKey.column);
    int id = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.insert(TableAlias.table, map);
      },
    );
    model.id = id;
    return model;
  }

  /// returns number of changes
  Future<int> update() async {
    if (id <= 0) {
      throw ('update model "$title" has no id');
    }
    var count = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.update(TableAlias.table, toMap(),
            where: '${TableAlias.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  /// <pre> select alias models ordered by row "distance" to given gps
  /// "distance" contains c² of a² + b²
  /// which is NOT the distance but serves to compare distances approximately
  ///
  /// (table.lat - gps.lat)*(table.lat - gps.lat) + (table.lon - gps.lon)*(table.lon - gps.lon)
  /// </pre>
  static Future<List<ModelAlias>> nextAlias(
      {required GPS gps,
      int limit = 1,
      int offset = 0,
      includeInactive = false}) async {
    var lat = gps.lat;
    var lon = gps.lon;
    var latCol = TableAlias.latitude.column;
    var lonCol = TableAlias.longitude.column;
    var mathSql =
        '($latCol - $lat)*($latCol - $lat) + ($lonCol - $lon)*($latCol - $lon)';
    var mathCol = 'distance';
    var isActiveCol = 'isActive';
    var rows = await DB.execute((txn) async {
      if (!includeInactive) {
        return await txn.rawQuery('''
SELECT ${TableAlias.columns.join(', ')}, ${TableAliasGroup.isActive} AS $isActiveCol, $mathSql AS $mathCol FROM ${TableAlias.table}
LEFT JOIN ${TableAliasGroup.table} ON ${TableAlias.idAliasGroup} = ${TableAliasGroup.primaryKey}
WHERE $mathCol <= ? AND $isActiveCol = ?
ORDER BY $mathCol
LIMIT ?,?
          ''', [
          AppSettings.distanceTreshold * AppSettings.distanceTreshold,
          DB.boolToInt(includeInactive),
          limit,
          offset
        ]);
      } else {
        return await txn.query(TableAlias.table,
            columns: [...TableAlias.columns, '$mathSql as $mathCol'],
            where: '$mathCol <= ?',
            whereArgs: [
              AppSettings.distanceTreshold * AppSettings.distanceTreshold
            ],
            orderBy: '$mathCol ASC',
            limit: limit,
            offset: offset);
      }
    });
    var models = <ModelAlias>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('nextAlias fromMap $e', stk);
      }
    }
    return models;
  }
}
