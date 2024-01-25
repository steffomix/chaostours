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
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_location.dart';
import 'package:chaostours/model/model_group.dart';
import 'package:sqflite/sqflite.dart';

class ModelLocationGroup implements ModelGroup {
  static final Logger logger = Logger.logger<ModelLocationGroup>();
  int _id = 0;
  @override
  int get id => _id;
  bool isActive = true;
  String idCalendar = '';
  LocationPrivacy privacy = LocationPrivacy.public;
  @override
  String title = '';
  @override
  String description = '';

  bool calendarHtml = false;
  bool calendarGps = false;
  bool calendarTimeStart = false;
  bool calendarTimeEnd = false;
  bool calendarAllDay = false;
  bool calendarDuration = false;
  bool calendarAddress = false;
  bool calendarFullAddress = false;
  bool calendarTrackpointNotes = false;
  bool calendarLocation = false;
  bool calendarLocationNearby = false;
  bool calendarNearbyLocationDescription = false;
  bool calendarLocationDescription = false;
  bool calendarUsers = false;
  bool calendarUserNotes = false;
  bool calendarUserDescription = false;
  bool calendarTasks = false;
  bool calendarTaskNotes = false;
  bool calendarTaskDescription = false;

  ModelLocationGroup({
    this.idCalendar = '',
    this.isActive = true,
    this.privacy = LocationPrivacy.public,
    this.title = '',
    this.description = '',
    this.calendarHtml = false,
    this.calendarGps = false,
    this.calendarTimeStart = false,
    this.calendarTimeEnd = false,
    this.calendarAllDay = false,
    this.calendarDuration = false,
    this.calendarAddress = false,
    this.calendarFullAddress = false,
    this.calendarTrackpointNotes = false,
    this.calendarLocation = false,
    this.calendarLocationNearby = false,
    this.calendarNearbyLocationDescription = false,
    this.calendarLocationDescription = false,
    this.calendarUsers = false,
    this.calendarUserNotes = false,
    this.calendarUserDescription = false,
    this.calendarTasks = false,
    this.calendarTaskNotes = false,
    this.calendarTaskDescription = false,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableLocationGroup.primaryKey.column: id,
      TableLocationGroup.idCalendar.column: idCalendar,
      TableLocationGroup.isActive.column: TypeAdapter.serializeBool(isActive),
      TableLocationGroup.privacy.column: privacy.level,
      TableLocationGroup.title.column: title,
      TableLocationGroup.description.column: description,
      TableLocationGroup.withCalendarHtml.column:
          TypeAdapter.serializeBool(calendarHtml),
      TableLocationGroup.withCalendarGps.column:
          TypeAdapter.serializeBool(calendarGps),
      TableLocationGroup.withCalendarTimeStart.column:
          TypeAdapter.serializeBool(calendarTimeStart),
      TableLocationGroup.withCalendarTimeEnd.column:
          TypeAdapter.serializeBool(calendarTimeEnd),
      TableLocationGroup.withCalendarAllDay.column:
          TypeAdapter.serializeBool(calendarAllDay),
      TableLocationGroup.withCalendarDuration.column:
          TypeAdapter.serializeBool(calendarDuration),
      TableLocationGroup.withCalendarAddress.column:
          TypeAdapter.serializeBool(calendarAddress),
      TableLocationGroup.withCalendarFullAddress.column:
          TypeAdapter.serializeBool(calendarFullAddress),
      TableLocationGroup.withCalendarTrackpointNotes.column:
          TypeAdapter.serializeBool(calendarTrackpointNotes),
      TableLocationGroup.withCalendarLocation.column:
          TypeAdapter.serializeBool(calendarLocation),
      TableLocationGroup.withCalendarLocationNearby.column:
          TypeAdapter.serializeBool(calendarLocationNearby),
      TableLocationGroup.withCalendarNearbyLocationDescription.column:
          TypeAdapter.serializeBool(calendarNearbyLocationDescription),
      TableLocationGroup.withCalendarLocationDescription.column:
          TypeAdapter.serializeBool(calendarLocationDescription),
      TableLocationGroup.withCalendarUsers.column:
          TypeAdapter.serializeBool(calendarUsers),
      TableLocationGroup.withCalendarUserNotes.column:
          TypeAdapter.serializeBool(calendarUserNotes),
      TableLocationGroup.withCalendarUserDescription.column:
          TypeAdapter.serializeBool(calendarUserDescription),
      TableLocationGroup.withCalendarTasks.column:
          TypeAdapter.serializeBool(calendarTasks),
      TableLocationGroup.withCalendarTaskNotes.column:
          TypeAdapter.serializeBool(calendarTaskNotes),
      TableLocationGroup.withCalendarTaskDescription.column:
          TypeAdapter.serializeBool(calendarTaskDescription),
    };
  }

  static ModelLocationGroup fromMap(Map<String, Object?> map) {
    var model = ModelLocationGroup(
      idCalendar: TypeAdapter.deserializeString(
          map[TableLocationGroup.idCalendar.column]),
      isActive:
          TypeAdapter.deserializeBool(map[TableLocationGroup.isActive.column]),
      privacy: LocationPrivacy.byId(map[TableLocationGroup.privacy.column]),
      title:
          TypeAdapter.deserializeString(map[TableLocationGroup.title.column]),
      description: TypeAdapter.deserializeString(
          map[TableLocationGroup.description.column]),
      calendarHtml: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarHtml.column]),
      calendarGps: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarGps.column]),
      calendarTimeStart: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarTimeStart.column]),
      calendarTimeEnd: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarTimeEnd.column]),
      calendarAllDay: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarAllDay.column]),
      calendarDuration: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarDuration.column]),
      calendarAddress: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarAddress.column]),
      calendarFullAddress: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarFullAddress.column]),
      calendarTrackpointNotes: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarTrackpointNotes.column]),
      calendarLocation: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarLocation.column]),
      calendarLocationNearby: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarLocationNearby.column]),
      calendarNearbyLocationDescription: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarNearbyLocationDescription.column]),
      calendarLocationDescription: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarLocationDescription.column]),
      calendarUsers: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarUsers.column]),
      calendarUserNotes: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarUserNotes.column]),
      calendarUserDescription: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarUserDescription.column]),
      calendarTasks: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarTasks.column]),
      calendarTaskNotes: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarTaskNotes.column]),
      calendarTaskDescription: TypeAdapter.deserializeBool(
          map[TableLocationGroup.withCalendarTaskDescription.column]),
    );
    model._id =
        TypeAdapter.deserializeInt(map[TableLocationGroup.primaryKey.column]);
    return model;
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn
            .query(TableLocationGroup.table, columns: ['count(*) as $col']);

        if (rows.isNotEmpty) {
          return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelLocationGroup?> byId(int id, [Transaction? txn]) async {
    Future<ModelLocationGroup?> select(Transaction txn) async {
      final rows = await txn.query(TableLocationGroup.table,
          columns: TableLocationGroup.columns,
          where: '${TableLocationGroup.primaryKey.column} = ?',
          whereArgs: [id]);

      return rows.isEmpty ? null : fromMap(rows.first);
    }

    return txn != null
        ? await select(txn)
        : await DB.execute(
            (Transaction txn) async {
              return await select(txn);
            },
          );
  }

  static Future<List<ModelLocationGroup>> byIdList(List<int> ids) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableLocationGroup.table,
            columns: TableLocationGroup.columns,
            where:
                '${TableLocationGroup.primaryKey.column} IN (${List.filled(ids.length, '?').join(', ')})',
            whereArgs: ids);
      },
    );
    List<ModelLocationGroup> models = [];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('byIdList iter through rows: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelLocationGroup>> _search(String text,
      {int offset = 0, int limit = 50}) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableLocationGroup.table,
            where:
                '${TableLocationGroup.title} like ? OR ${TableLocationGroup.description} like ?',
            whereArgs: [text, text],
            offset: offset,
            limit: limit);
      },
    );
    var models = <ModelLocationGroup>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelLocationGroup>> select(
      {int offset = 0,
      int limit = 50,
      bool activated = true,
      String search = ''}) async {
    if (search.isNotEmpty) {
      return await ModelLocationGroup._search(search,
          offset: offset, limit: limit);
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableLocationGroup.table,
            columns: TableLocationGroup.columns,
            where: '${TableLocationGroup.isActive.column} = ?',
            whereArgs: [TypeAdapter.serializeBool(activated)],
            limit: limit,
            offset: offset,
            orderBy: TableLocationGroup.title.column);
      },
    );
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
  }

  Future<ModelLocationGroup> insert() async {
    var map = toMap();
    map.removeWhere(
        (key, value) => key == TableLocationGroup.primaryKey.column);
    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableLocationGroup.table, map);
      },
    );
    return this;
  }

  Future<int> update() async {
    if (id <= 0) {
      throw ('update model "$title" has no id');
    }
    var count = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.update(TableLocationGroup.table, toMap(),
            where: '${TableLocationGroup.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    return count;
  }

  Future<List<int>> locationIds() async {
    var col = TableLocationLocationGroup.idLocation.column;
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableLocationLocationGroup.table,
          columns: [col],
          where: '${TableLocationLocationGroup.idLocationGroup.column} = ?',
          whereArgs: [id]);
    });
    return rows.map((e) => TypeAdapter.deserializeInt(e[col])).toList();
  }

  Future<int> locationCount() async {
    return await DB.execute<int>((txn) async {
      var col = 'ct';
      final rows = await txn.query(TableLocationLocationGroup.table,
          columns: ['count(*) as $col'],
          where: '${TableLocationLocationGroup.idLocationGroup.column} = ?',
          whereArgs: [id]);
      return TypeAdapter.deserializeInt(rows.firstOrNull?[col]);
    });
  }

  /// select a list of distinct Groups from a List of Location IDs
  static Future<List<ModelLocationGroup>> groups(
      List<ModelLocation> locationModels) async {
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      var ids = locationModels
          .map(
            (e) => e.id,
          )
          .toList();
      var q = '''
SELECT ${TableLocationGroup.columns.join(', ')} FROM ${TableLocationLocationGroup.table}
LEFT JOIN ${TableLocationGroup.table} ON ${TableLocationLocationGroup.idLocationGroup} = ${TableLocationGroup.primaryKey}
WHERE ${TableLocationLocationGroup.idLocation} IN (${List.filled(ids.length, '?').join(', ')})
GROUP by  ${TableLocationGroup.primaryKey}
ORDER BY ${TableLocationGroup.primaryKey}
''';
      return await txn.rawQuery(q, ids);
    });
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
  }

  /// clear calendar ids after database import
  static Future<void> deleteAllcalendarSettings() async {
    await DB.execute(
      (txn) async {
        await txn.update(
            TableTrackPointCalendar.table,
            {
              TableTrackPointCalendar.idCalendar.column: '',
              TableTrackPointCalendar.idEvent.column: ''
            },
            where: '1');

        var fields = <String, Object?>{};
        for (var column in TableLocationGroup.calendarFields()) {
          fields[column.column] = '';
        }
        await txn.update(TableLocationGroup.table, fields, where: '1');
      },
    );
    await Cache.backgroundCalendarLastEventIds.save<List<CalendarEventId>>([]);
  }

  ModelLocationGroup clone() {
    return fromMap(toMap());
  }
}
