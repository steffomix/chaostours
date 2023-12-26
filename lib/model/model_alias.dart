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

///
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

enum AliasPrivacy {
  /// send notification, make record, publish to calendar
  public(1, Color.fromARGB(255, 0, 166, 0)),

  /// send notification, make record
  privat(2, Color.fromARGB(255, 0, 0, 166)),

  /// send notification
  restricted(3, Color.fromARGB(255, 166, 0, 166)),

  /// do nothing
  none(4, Colors.black); // no alias found

  static final Logger logger = Logger.logger<AliasPrivacy>();
  final int level;
  final Color color;
  const AliasPrivacy(this.level, this.color);
  static final int _saveId = AliasPrivacy.restricted.level;

  static AliasPrivacy byId(Object? value) {
    int id = DB.parseInt(value, fallback: 3);
    int idChecked = max(1, min(3, id));
    return byValue(idChecked == id ? idChecked : _saveId);
  }

  static AliasPrivacy byValue(int id) {
    try {
      return AliasPrivacy.values.firstWhere((status) => status.level == id);
    } catch (e, stk) {
      logger.error('invalid value $id: $e', stk);
      return AliasPrivacy.restricted;
    }
  }
}

class ModelAlias {
  static Logger logger = Logger.logger<ModelAlias>();
  int _id = 0;
  int get id => _id;
  // lazy loaded group
  List<ModelAliasGroup> aliasGroups = [];
  GPS gps;
  int radius = 50;
  DateTime lastVisited;
  int timesVisited = 0;
  String calendarId = '';
  String title = '';
  String description = '';

  /// group values
  AliasPrivacy privacy = AliasPrivacy.restricted;
  bool isActive = true;

  /// temporary set during search for nearest Alias
  int sortDistance = 0;
  int _countVisited = 0;
  int get countVisited => _countVisited;

  ModelAlias({
    required this.gps,
    required this.lastVisited,
    required this.title,
    this.isActive = true,
    this.privacy = AliasPrivacy.public,
    this.radius = 50,
    this.timesVisited = 0,
    this.description = '',
  });

  static ModelAlias fromMap(Map<String, Object?> map) {
    var model = ModelAlias(
        isActive: DB.parseBool(map[TableAlias.isActive.column],
            fallback: DB.parseBool(true)),
        gps: GPS(DB.parseDouble(map[TableAlias.latitude.column]),
            DB.parseDouble(map[TableAlias.longitude.column])),
        radius: DB.parseInt(map[TableAlias.radius.column], fallback: 10),
        privacy: AliasPrivacy.byId(map[TableAlias.privacy.column]),
        lastVisited: DB.intToTime(map[TableAlias.lastVisited.column]),
        timesVisited: DB.parseInt(map[TableAlias.timesVisited.column]),
        title: DB.parseString(map[TableAlias.title.column]),
        description: DB.parseString(map[TableAlias.description.column]));
    model._id = DB.parseInt(map[TableAlias.primaryKey.column]);
    return model;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableAlias.primaryKey.column: id,
      TableAlias.isActive.column: DB.boolToInt(isActive),
      TableAlias.latitude.column: gps.lat,
      TableAlias.longitude.column: gps.lon,
      TableAlias.radius.column: radius,
      TableAlias.privacy.column: privacy.level,
      TableAlias.lastVisited.column: DB.timeToInt(lastVisited),
      TableAlias.timesVisited.column: timesVisited,
      TableAlias.title.column: title,
      TableAlias.description.column: description
    };
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows =
            await txn.query(TableAlias.table, columns: ['count(*) as $col']);
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
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTrackPointAlias.table,
            columns: ['count(*) as $col'],
            where: '${TableTrackPointAlias.idAlias.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return DB.parseInt(rows.first[col], fallback: 0);
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
        var alias = fromMap(rows.first);
        alias._countVisited = await ModelTrackPoint.count(alias: alias);
        return alias;
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
                '${TableAlias.primaryKey.column} IN (${List.filled(ids.length, '?').join(', ')})',
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

  /// find trackpoints by aliasId
  Future<List<ModelTrackPoint>> trackpoints(
      {int offset = 0, int limit = 20}) async {
    const idCol = 'id';
    var rows =
        await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(TableTrackPointAlias.table,
          columns: ['${TableTrackPointAlias.idTrackPoint.column} as $idCol'],
          where: '${TableTrackPointAlias.idAlias.column} = ?',
          whereArgs: [id],
          limit: limit,
          offset: offset);
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
    var area = GpsArea(
        latitude: gps.lat, longitude: gps.lon, distanceInMeters: radius);
    var table = TableAlias.table;
    var latCol = TableAlias.latitude.column;
    var lonCol = TableAlias.longitude.column;

    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(table,
            columns: TableAlias.columns,
            where:
                '$latCol > ? AND $latCol < ? AND $lonCol > ? AND $lonCol < ?',
            whereArgs: [
              area.southLatitudeBorder,
              area.northLatitudeBorder,
              area.westLongitudeBorder,
              area.eastLongitudeBorder
            ]);
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
      {int offset = 0,
      int limit = 50,
      bool activated = true,
      bool lastVisited = true,
      String search = ''}) async {
    var colCountVisited = 'countVisited';
    var rows = await DB.execute(
      (txn) async {
        final trueSearch = '%$search%';
        final searchQuery = search.isEmpty
            ? ''
            : ' AND (${TableAlias.title.column} LIKE ? OR ${TableAlias.description.column} LIKE ?) ';
        final searchArgs = search.isEmpty ? [] : [trueSearch, trueSearch];
        final args = [DB.boolToInt(activated), ...searchArgs, limit, offset];
        final q = '''
SELECT ${TableAlias.columns.join(', ')} , COUNT(${TableTrackPointAlias.idAlias}) as $colCountVisited FROM ${TableAlias.table}
LEFT JOIN ${TableTrackPointAlias.table} ON ${TableTrackPointAlias.idAlias} = ${TableAlias.id}
-- LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointAlias.idTrackPoint}
WHERE ${TableAlias.isActive.column} = ? $searchQuery
GROUP BY ${TableAlias.id}  -- (${TableTrackPoint.timeStart} / (60 * 60 * 24))
ORDER BY ${lastVisited ? '${TableAlias.lastVisited.column} DESC' : '${TableAlias.title.column} ASC'}
LIMIT ?
OFFSET ?
''';
        return await txn.rawQuery(q, args);
      },
    );
    List<ModelAlias> models = [];
    ModelAlias model;
    for (var row in rows) {
      model = fromMap(row);
      model._countVisited = DB.parseInt(row[colCountVisited]);
      models.add(model);
    }
    return models;
/*
    var rows =
        await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(TableAlias.table,
          columns: TableAlias.columns,
          where: '${TableAlias.isActive.column} = ? $searchQuery',
          whereArgs: [DB.boolToInt(activated), ...searchArgs],
          orderBy: lastVisited
              ? '${TableAlias.lastVisited.column} DESC'
              : '${TableAlias.title.column} ASC',
          offset: offset,
          limit: limit);
    });
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
    */
  }

  /// select deep activated, respects group activation
  static Future<List<ModelAlias>> selsectActivated(
      {bool isActive = true}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      var q = '''
SELECT ${TableAlias.columns.join(', ')} FROM ${TableAliasAliasGroup.table}
LEFT JOIN ${TableAlias.table} ON ${TableAlias.primaryKey} = ${TableAliasAliasGroup.idAlias}
LEFT JOIN ${TableAliasGroup.table} ON ${TableAliasAliasGroup.idAliasGroup} =  ${TableAliasGroup.primaryKey}
WHERE ${TableAlias.isActive} = ? AND ${TableAliasGroup.isActive} = ?
''';

      return await txn.rawQuery(q, List.filled(2, DB.boolToInt(isActive)));
    });
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
  }

  Future<ModelAlias> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableAlias.primaryKey.column);

    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableAlias.table, map);
        await txn.insert(TableAliasAliasGroup.table, {
          TableAliasAliasGroup.idAlias.column: _id,
          TableAliasAliasGroup.idAliasGroup.column: 1
        });
      },
    );
    return this;
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

  /// <pre>
  /// select alias of an area in meters and sort the result by distance.
  /// Does not work with paging
  /// </pre>
  static Future<List<ModelAlias>> byArea(
      {required GPS gps,
      includeInactive = true,
      int area = 1000,
      int softLimit = 0}) async {
    var area =
        GpsArea(latitude: gps.lat, longitude: gps.lon, distanceInMeters: 1000);
    var latCol = TableAlias.latitude.column;
    var lonCol = TableAlias.longitude.column;
    var whereArea =
        ' $latCol > ? AND $latCol < ? AND $lonCol > ? AND $lonCol < ? ';
    var isActiveCol = 'isActive';
    var rows = await DB.execute((txn) async {
      if (!includeInactive) {
        return await txn.rawQuery('''
SELECT ${TableAlias.columns.join(', ')}, ${TableAliasGroup.isActive} AS $isActiveCol  FROM ${TableAlias.table}
LEFT JOIN ${TableAliasGroup.table} ON ${TableAlias.idAliasGroup} = ${TableAliasGroup.primaryKey}
WHERE $isActiveCol = ? AND $whereArea
          ''', [
          DB.boolToInt(includeInactive),
          area.southLatitudeBorder,
          area.northLatitudeBorder,
          area.westLongitudeBorder,
          area.eastLongitudeBorder
        ]);
      } else {
        return await txn.query(TableAlias.table,
            columns: TableAlias.columns,
            where: whereArea,
            whereArgs: [
              area.southLatitudeBorder,
              area.northLatitudeBorder,
              area.westLongitudeBorder,
              area.eastLongitudeBorder,
            ]);
      }
    });
    var models = <ModelAlias>[];
    for (var row in rows) {
      try {
        var model = fromMap(row);
        model.sortDistance = GPS.distance(gps, model.gps).round();
        models.add(model);
      } catch (e, stk) {
        logger.error('nextAlias fromMap $e', stk);
      }
    }
    if (models.isNotEmpty) {
      models.sort((a, b) => a.sortDistance.compareTo(b.sortDistance));
    }

    if (softLimit > 0 && models.length >= softLimit) {
      return models.sublist(0, softLimit);
    }
    return models;
  }

  /// select ALL groups from this alias for checkbox selection.
  Future<List<int>> groupIds() async {
    var col = TableAliasAliasGroup.idAliasGroup.column;
    final ids = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableAliasAliasGroup.table,
          columns: [col],
          where: '${TableAliasAliasGroup.idAlias.column} = ?',
          whereArgs: [id]);
    });
    if (ids.isEmpty) {
      return <int>[];
    }
    return ids.map((e) => DB.parseInt(e[col])).toList();
  }

  Future<int> addGroup(ModelAliasGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.insert(TableAliasAliasGroup.table, {
          TableAliasAliasGroup.idAlias.column: id,
          TableAliasAliasGroup.idAliasGroup.column: group.id
        });
        return c;
      } catch (e) {
        logger.warn('addGroup: $e');
        return 0;
      }
    });
  }

  Future<int> removeGroup(ModelAliasGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.delete(
          TableAliasAliasGroup.table,
          where:
              '${TableAliasAliasGroup.idAlias.column} = ? AND ${TableAliasAliasGroup.idAliasGroup.column} = ?',
          whereArgs: [id, group.id],
        );
        return c;
      } catch (e) {
        logger.warn('addGroup: $e');
        return 0;
      }
    });
  }
}
