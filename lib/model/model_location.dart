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

import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';

///
import 'package:chaostours/calendar.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_location_group.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';

enum LocationPrivacy implements EnumUserSetting<LocationPrivacy> {
  /// send notification, make record, publish to calendar
  public(1, Color.fromARGB(255, 0, 166, 0),
      Text('Publish to calendar, notification, make a trackpoint record')),

  /// send notification, make record
  privat(2, Color.fromARGB(255, 0, 0, 166),
      Text('Notification, make a trackpoint record')),

  /// send notification
  restricted(
      3, Color.fromARGB(255, 166, 0, 166), Text('Make a trackpoint record')),

  /// do nothing
  none(4, Colors.black, Text('Does nothing')); // no location found

  static final Logger logger = Logger.logger<LocationPrivacy>();
  final int level;
  final Color color;
  @override
  final Widget title;
  const LocationPrivacy(this.level, this.color, this.title);
  static final int _saveId = LocationPrivacy.restricted.level;

  static LocationPrivacy byId(Object? value) {
    int id = TypeAdapter.deserializeInt(value, fallback: 3);
    int idChecked = max(1, min(3, id));
    return byValue(idChecked == id ? idChecked : _saveId);
  }

  static LocationPrivacy byValue(int id) {
    try {
      return LocationPrivacy.values.firstWhere((status) => status.level == id);
    } catch (e, stk) {
      logger.error('invalid value $id: $e', stk);
      return LocationPrivacy.restricted;
    }
  }

  static LocationPrivacy? byName(String name) {
    for (var value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}

class ModelLocation implements Model {
  static Logger logger = Logger.logger<ModelLocation>();
  int _id = 0;
  @override
  int get id => _id;
  // lazy loaded group
  List<ModelLocationGroup> locationGroups = [];

  DateTime? dateCreated;

  int timesVisited = 0;
  DateTime? lastVisited;

  GPS gps;
  int radius = 50;
  String calendarId = '';
  @override
  String title = '';
  @override
  String description = '';
  @override
  String trackpointNotes = '';

  /// group values
  LocationPrivacy privacy = LocationPrivacy.privat;
  bool isActive = true;

  /// temporary set during search for nearest Location
  int sortDistance = 0;

  ModelLocation({
    required this.gps,
    required this.title,
    this.isActive = true,
    this.dateCreated,
    this.privacy = LocationPrivacy.privat,
    this.radius = 50,
    this.timesVisited = 0,
    this.description = '',
  });

  static ModelLocation fromMap(Map<String, Object?> map) {
    var model = ModelLocation(
        isActive: TypeAdapter.deserializeBool(
            map[TableLocation.isActive.column],
            fallback: TypeAdapter.deserializeBool(true)),
        dateCreated:
            TypeAdapter.dbIntToTime(map[TableLocation.dateCreated.column]),
        gps: GPS(
            TypeAdapter.deserializeDouble(map[TableLocation.latitude.column]),
            TypeAdapter.deserializeDouble(map[TableLocation.longitude.column])),
        radius: TypeAdapter.deserializeInt(map[TableLocation.radius.column],
            fallback: 10),
        privacy: LocationPrivacy.byId(map[TableLocation.privacy.column]),
        title: TypeAdapter.deserializeString(map[TableLocation.title.column]),
        description: TypeAdapter.deserializeString(
            map[TableLocation.description.column]));
    model._id =
        TypeAdapter.deserializeInt(map[TableLocation.primaryKey.column]);
    return model;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableLocation.primaryKey.column: id,
      TableLocation.isActive.column: TypeAdapter.serializeBool(isActive),
      TableLocation.dateCreated.column:
          TypeAdapter.dbTimeToInt(dateCreated ?? DateTime.now()),
      TableLocation.latitude.column: gps.lat,
      TableLocation.longitude.column: gps.lon,
      TableLocation.radius.column: radius,
      TableLocation.privacy.column: privacy.level,
      TableLocation.title.column: title,
      TableLocation.description.column: description
    };
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows =
            await txn.query(TableLocation.table, columns: ['count(*) as $col']);
        if (rows.isNotEmpty) {
          return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
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
        return await txn.query(TableTrackPointLocation.table,
            columns: ['count(*) as $col'],
            where: '${TableTrackPointLocation.idLocation.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
    }
    return 0;
  }

  ///
  static Future<ModelLocation?> byId(int id) async {
    return await DB.execute(
      (Transaction txn) async {
        const colTimesVisited = 'timesVisited';
        const colLastVisited = 'lastVisited';
        final sql = '''
          SELECT ${TableLocation.columns.join(', ')}, 
            COUNT(${TableTrackPointLocation.idLocation}) AS $colTimesVisited,
            MAX(${TableTrackPoint.timeStart}) AS $colLastVisited
          FROM ${TableLocation.table}
          LEFT JOIN ${TableTrackPointLocation.table} ON ${TableTrackPointLocation.idLocation} = ${TableLocation.id}
          LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}
          WHERE ${TableLocation.id} = ?
          GROUP BY ${TableLocation.id}
''';
        final rows = await txn.rawQuery(sql, [id]);

        if (rows.isEmpty) {
          return null;
        }

        final model = fromMap(rows.first);
        model.lastVisited = TypeAdapter.dbIntToTime(rows.first[colLastVisited]);
        model.timesVisited =
            TypeAdapter.deserializeInt(rows.first[colTimesVisited]);
        return model;
      },
    );
  }

  ///
  static Future<List<ModelLocation>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelLocation>[];
    }
    return await DB.execute(
      (Transaction txn) async {
        const colTimesVisited = 'timesVisited';
        const colLastVisited = 'lastVisited';
        final sql = '''
          SELECT ${TableLocation.columns.join(', ')}, 
            COUNT(${TableTrackPointLocation.idLocation}) AS $colTimesVisited,
            MAX(${TableTrackPoint.timeStart}) AS $colLastVisited
          FROM ${TableLocation.table}
          LEFT JOIN ${TableTrackPointLocation.table} ON ${TableTrackPointLocation.idLocation} = ${TableLocation.id}
          LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}
          WHERE ${TableLocation.id} IN (${List.filled(ids.length, '?').join(', ')})
          GROUP BY ${TableLocation.id}
''';
        final rows = await txn.rawQuery(sql, ids);

        List<ModelLocation> models = [];
        for (var row in rows) {
          final model = fromMap(row);
          model.lastVisited =
              TypeAdapter.dbIntToTime(rows.first[colLastVisited]);
          model.timesVisited =
              TypeAdapter.deserializeInt(rows.first[colTimesVisited]);
          models.add(model);
        }
        return models;
      },
    );
  }

  /// find trackpoints by locationId
  Future<List<ModelTrackPoint>> trackpoints(
      {int offset = 0, int limit = 20}) async {
    const idCol = 'id';
    var rows =
        await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
      return await txn.query(TableTrackPointLocation.table,
          columns: ['${TableTrackPointLocation.idTrackPoint.column} as $idCol'],
          where: '${TableTrackPointLocation.idLocation.column} = ?',
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
  static Future<List<ModelLocation>> byRadius(
      {required GPS gps, required int radius}) async {
    var area = GpsArea(
        latitude: gps.lat, longitude: gps.lon, distanceInMeters: radius);
    var table = TableLocation.table;
    var latCol = TableLocation.latitude.column;
    var lonCol = TableLocation.longitude.column;

    var rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(table,
            columns: TableLocation.columns,
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
    var rawModels = <ModelLocation>[];
    for (var row in rows) {
      rawModels.add(fromMap(row));
    }
    var models = <ModelLocation>[];
    for (var model in rawModels) {
      if (GPS.distance(model.gps, gps) <= radius) {
        models.add(model);
      }
    }
    return models;
  }

  static Future<List<ModelLocation>> select(
      {int offset = 0,
      int limit = 50,
      bool activated = true,
      bool lastVisited = true,
      String search = ''}) async {
    var colCountVisited = 'countVisited';
    var colLastVisited = 'lastVisited';
    var rows = await DB.execute(
      (txn) async {
        final trueSearch = '%$search%';
        final searchQuery = search.isEmpty
            ? ''
            : ' AND (${TableLocation.title.column} LIKE ? OR ${TableLocation.description.column} LIKE ?) ';
        final searchArgs = search.isEmpty ? [] : [trueSearch, trueSearch];
        final args = [
          TypeAdapter.serializeBool(activated),
          ...searchArgs,
          limit,
          offset
        ];
        final q = '''
SELECT ${TableLocation.columns.join(', ')} , 
COUNT(${TableTrackPointLocation.idLocation}) as $colCountVisited,
MAX(${TableTrackPoint.timeStart}) as $colLastVisited
FROM ${TableLocation.table}
LEFT JOIN ${TableTrackPointLocation.table} ON ${TableTrackPointLocation.idLocation} = ${TableLocation.id}
LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}
WHERE ${TableLocation.isActive} = ? $searchQuery
GROUP BY ${TableLocation.id}  -- (${TableTrackPoint.timeStart} / (60 * 60 * 24))
ORDER BY ${lastVisited ? '${TableTrackPoint.timeStart.column} DESC' : '${TableLocation.title.column} ASC'}
LIMIT ?
OFFSET ?
''';
        return await txn.rawQuery(q, args);
      },
    );
    List<ModelLocation> models = [];
    ModelLocation model;
    for (var row in rows) {
      model = fromMap(row);
      model.timesVisited = TypeAdapter.deserializeInt(row[colCountVisited]);
      model.lastVisited = TypeAdapter.dbIntToTime(rows.first[colLastVisited]);
      models.add(model);
    }
    return models;
  }

  /// select deep activated, respects group activation
  static Future<List<ModelLocation>> selsectActivated(
      {bool isActive = true}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      var q = '''
SELECT ${TableLocation.columns.join(', ')} FROM ${TableLocationLocationGroup.table}
LEFT JOIN ${TableLocation.table} ON ${TableLocation.primaryKey} = ${TableLocationLocationGroup.idLocation}
LEFT JOIN ${TableLocationGroup.table} ON ${TableLocationLocationGroup.idLocationGroup} =  ${TableLocationGroup.primaryKey}
WHERE ${TableLocation.isActive} = ? AND ${TableLocationGroup.isActive} = ?
''';

      return await txn.rawQuery(
          q, List.filled(2, TypeAdapter.serializeBool(isActive)));
    });
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
  }

  Future<ModelLocation> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableLocation.primaryKey.column);

    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableLocation.table, map);
        await txn.insert(TableLocationLocationGroup.table, {
          TableLocationLocationGroup.idLocation.column: _id,
          TableLocationLocationGroup.idLocationGroup.column: 1
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
        return await txn.update(TableLocation.table, toMap(),
            where: '${TableLocation.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  static Future<List<ModelLocation>> byArea(
      {required GPS gps,
      bool? isActive,
      int gpsArea = 10000,
      int limit = 300,
      int softLimit = 0}) async {
    final area = GpsArea(
        latitude: gps.lat, longitude: gps.lon, distanceInMeters: gpsArea);
    final searchActive = isActive == null
        ? ''
        : '${TableLocationGroup.isActive} = ? AND ${TableLocation.isActive} = ? AND';
    const colTimesVisited = 'countVisited';
    const colLastVisited = 'lastVisited';
    final rows = await DB.execute((txn) async {
      final q = '''
SELECT ${TableLocation.columns.join(', ')},
  COUNT(${TableTrackPointLocation.idLocation}) AS $colTimesVisited,
  MAX(${TableTrackPoint.timeStart}) AS $colLastVisited
FROM ${TableLocation.table}
  LEFT JOIN ${TableTrackPointLocation.table} ON ${TableTrackPointLocation.idLocation} = ${TableLocation.id}
  LEFT JOIN ${TableTrackPoint.table} ON ${TableTrackPoint.id} = ${TableTrackPointLocation.idTrackPoint}  
  LEFT JOIN ${TableLocationLocationGroup.table} ON ${TableLocation.id} = ${TableLocationLocationGroup.idLocation}
  LEFT JOIN ${TableLocationGroup.table} ON ${TableLocationGroup.id} = ${TableLocationLocationGroup.idLocationGroup}
WHERE 
$searchActive
${TableLocation.latitude} > ? AND 
${TableLocation.latitude} < ? AND 
${TableLocation.longitude} > ? AND 
${TableLocation.longitude} < ? 
GROUP BY ${TableLocation.id}
LIMIT ?
''';
      return await txn.rawQuery(q, [
        ...isActive == null
            ? []
            : List.filled(2, TypeAdapter.serializeBool(isActive)),
        area.southLatitudeBorder,
        area.northLatitudeBorder,
        area.westLongitudeBorder,
        area.eastLongitudeBorder,
        limit
      ]);
    });
    var models = <ModelLocation>[];
    for (var row in rows) {
      try {
        var model = fromMap(row);
        model.sortDistance = GPS.distance(gps, model.gps).round();
        model.lastVisited = TypeAdapter.dbIntToTime(rows.first[colLastVisited]);
        model.timesVisited =
            TypeAdapter.deserializeInt(rows.first[colTimesVisited]);
        models.add(model);
      } catch (e, stk) {
        logger.error('next location fromMap $e', stk);
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

  /// select ALL groups from this location for checkbox selection.
  Future<List<int>> groupIds() async {
    var col = TableLocationLocationGroup.idLocationGroup.column;
    final ids = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableLocationLocationGroup.table,
          columns: [col],
          where: '${TableLocationLocationGroup.idLocation.column} = ?',
          whereArgs: [id]);
    });
    if (ids.isEmpty) {
      return <int>[];
    }
    return ids.map((e) => TypeAdapter.deserializeInt(e[col])).toList();
  }

  Future<int> addGroup(ModelLocationGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.insert(TableLocationLocationGroup.table, {
          TableLocationLocationGroup.idLocation.column: id,
          TableLocationLocationGroup.idLocationGroup.column: group.id
        });
        return c;
      } catch (e) {
        logger.warn('addGroup: $e');
        return 0;
      }
    });
  }

  Future<int> removeGroup(ModelLocationGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.delete(
          TableLocationLocationGroup.table,
          where:
              '${TableLocationLocationGroup.idLocation.column} = ? AND ${TableLocationLocationGroup.idLocationGroup.column} = ?',
          whereArgs: [id, group.id],
        );
        return c;
      } catch (e) {
        logger.warn('addGroup: $e');
        return 0;
      }
    });
  }

  static Future<List<CalendarEventId>> calendarIds(
      List<ModelLocation> models) async {
    List<int> ids = models
        .map(
          (e) => e.id,
        )
        .toList();
    List<String> params = List.filled(ids.length, '?');
    const idCalendar = 'idCalendar';
    const idLocationGroup = 'idLocationGroup';

    final q = '''SELECT 
        NULLIF(${TableLocationGroup.idCalendar}, '') as $idCalendar,
        ${TableLocationGroup.id} as $idLocationGroup
    FROM ${TableLocation.table}
    INNER JOIN ${TableLocationLocationGroup.table} ON ${TableLocation.id} = ${TableLocationLocationGroup.idLocation}
    LEFT JOIN ${TableLocationGroup.table} ON ${TableLocationLocationGroup.idLocationGroup} = ${TableLocationGroup.id}
    WHERE $idCalendar IS NOT NULL
    AND ${TableLocation.id} IN (${params.join(', ')})
    GROUP BY ${TableLocationGroup.idCalendar}
''';
    final rows = await DB.execute((txn) async {
      return await txn.rawQuery(q, ids);
    });
    List<CalendarEventId> result = [];
    for (var row in rows) {
      String parsedId = TypeAdapter.deserializeString(row[idCalendar]);

      if (parsedId.isNotEmpty) {
        result.add(CalendarEventId(
            locationGroupId:
                TypeAdapter.deserializeInt(row[idLocationGroup], fallback: -1),
            calendarId: TypeAdapter.deserializeString(row[idCalendar])));
      }
    }
    return result;
  }
}
