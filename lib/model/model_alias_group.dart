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
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_group.dart';
import 'package:sqflite/sqflite.dart';

class ModelAliasGroup implements ModelGroup {
  static final Logger logger = Logger.logger<ModelAliasGroup>();
  int _id = 0;
  @override
  int get id => _id;
  bool isActive = true;
  String idCalendar = '';
  AliasPrivacy privacy = AliasPrivacy.public;
  @override
  String title = '';
  @override
  String description = '';

  bool ensuredPrivacyCompliance = false;

  bool calendarHtml = false;
  bool calendarGps = false;
  bool calendarTimeStart = false;
  bool calendarTimeEnd = false;
  bool calendarAllDay = false;
  bool calendarDuration = false;
  bool calendarAddress = false;
  bool calendarFullAddress = false;
  bool calendarTrackpointNotes = false;
  bool calendarAlias = false;
  bool calendarAliasNearby = false;
  bool calendarNearbyAliasDescription = false;
  bool calendarAliasDescription = false;
  bool calendarUsers = false;
  bool calendarUserNotes = false;
  bool calendarUserDescription = false;
  bool calendarTasks = false;
  bool calendarTaskNotes = false;
  bool calendarTaskDescription = false;

  ModelAliasGroup({
    this.idCalendar = '',
    this.isActive = true,
    this.privacy = AliasPrivacy.public,
    this.title = '',
    this.description = '',
    this.ensuredPrivacyCompliance = false,
    this.calendarHtml = false,
    this.calendarGps = false,
    this.calendarTimeStart = false,
    this.calendarTimeEnd = false,
    this.calendarAllDay = false,
    this.calendarDuration = false,
    this.calendarAddress = false,
    this.calendarFullAddress = false,
    this.calendarTrackpointNotes = false,
    this.calendarAlias = false,
    this.calendarAliasNearby = false,
    this.calendarNearbyAliasDescription = false,
    this.calendarAliasDescription = false,
    this.calendarUsers = false,
    this.calendarUserNotes = false,
    this.calendarUserDescription = false,
    this.calendarTasks = false,
    this.calendarTaskNotes = false,
    this.calendarTaskDescription = false,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableAliasGroup.primaryKey.column: id,
      TableAliasGroup.idCalendar.column: idCalendar,
      TableAliasGroup.isActive.column: TypeAdapter.serializeBool(isActive),
      TableAliasGroup.privacy.column: privacy.level,
      TableAliasGroup.title.column: title,
      TableAliasGroup.description.column: description,
      TableAliasGroup.ensuredPrivacyCompliance.column:
          TypeAdapter.serializeBool(ensuredPrivacyCompliance),
      TableAliasGroup.withCalendarHtml.column:
          TypeAdapter.serializeBool(calendarHtml),
      TableAliasGroup.withCalendarGps.column:
          TypeAdapter.serializeBool(calendarGps),
      TableAliasGroup.withCalendarTimeStart.column:
          TypeAdapter.serializeBool(calendarTimeStart),
      TableAliasGroup.withCalendarTimeEnd.column:
          TypeAdapter.serializeBool(calendarTimeEnd),
      TableAliasGroup.withCalendarAllDay.column:
          TypeAdapter.serializeBool(calendarAllDay),
      TableAliasGroup.withCalendarDuration.column:
          TypeAdapter.serializeBool(calendarDuration),
      TableAliasGroup.withCalendarAddress.column:
          TypeAdapter.serializeBool(calendarAddress),
      TableAliasGroup.withCalendarFullAddress.column:
          TypeAdapter.serializeBool(calendarFullAddress),
      TableAliasGroup.withCalendarTrackpointNotes.column:
          TypeAdapter.serializeBool(calendarTrackpointNotes),
      TableAliasGroup.withCalendarAlias.column:
          TypeAdapter.serializeBool(calendarAlias),
      TableAliasGroup.withCalendarAliasNearby.column:
          TypeAdapter.serializeBool(calendarAliasNearby),
      TableAliasGroup.withCalendarNearbyAliasDescription.column:
          TypeAdapter.serializeBool(calendarNearbyAliasDescription),
      TableAliasGroup.withCalendarAliasDescription.column:
          TypeAdapter.serializeBool(calendarAliasDescription),
      TableAliasGroup.withCalendarUsers.column:
          TypeAdapter.serializeBool(calendarUsers),
      TableAliasGroup.withCalendarUserNotes.column:
          TypeAdapter.serializeBool(calendarUserNotes),
      TableAliasGroup.withCalendarUserDescription.column:
          TypeAdapter.serializeBool(calendarUserDescription),
      TableAliasGroup.withCalendarTasks.column:
          TypeAdapter.serializeBool(calendarTasks),
      TableAliasGroup.withCalendarTaskNotes.column:
          TypeAdapter.serializeBool(calendarTaskNotes),
      TableAliasGroup.withCalendarTaskDescription.column:
          TypeAdapter.serializeBool(calendarTaskDescription),
    };
  }

  static ModelAliasGroup fromMap(Map<String, Object?> map) {
    var model = ModelAliasGroup(
      idCalendar:
          TypeAdapter.deserializeString(map[TableAliasGroup.idCalendar.column]),
      isActive:
          TypeAdapter.deserializeBool(map[TableAliasGroup.isActive.column]),
      privacy: AliasPrivacy.byId(map[TableAliasGroup.privacy.column]),
      title: TypeAdapter.deserializeString(map[TableAliasGroup.title.column]),
      description: TypeAdapter.deserializeString(
          map[TableAliasGroup.description.column]),
      ensuredPrivacyCompliance: TypeAdapter.deserializeBool(
          map[TableAliasGroup.ensuredPrivacyCompliance.column]),
      calendarHtml: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarHtml.column]),
      calendarGps: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarGps.column]),
      calendarTimeStart: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarTimeStart.column]),
      calendarTimeEnd: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarTimeEnd.column]),
      calendarAllDay: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarAllDay.column]),
      calendarDuration: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarDuration.column]),
      calendarAddress: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarAddress.column]),
      calendarFullAddress: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarFullAddress.column]),
      calendarTrackpointNotes: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarTrackpointNotes.column]),
      calendarAlias: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarAlias.column]),
      calendarAliasNearby: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarAliasNearby.column]),
      calendarNearbyAliasDescription: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarNearbyAliasDescription.column]),
      calendarAliasDescription: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarAliasDescription.column]),
      calendarUsers: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarUsers.column]),
      calendarUserNotes: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarUserNotes.column]),
      calendarUserDescription: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarUserDescription.column]),
      calendarTasks: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarTasks.column]),
      calendarTaskNotes: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarTaskNotes.column]),
      calendarTaskDescription: TypeAdapter.deserializeBool(
          map[TableAliasGroup.withCalendarTaskDescription.column]),
    );
    model._id =
        TypeAdapter.deserializeInt(map[TableAliasGroup.primaryKey.column]);
    return model;
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn
            .query(TableAliasGroup.table, columns: ['count(*) as $col']);

        if (rows.isNotEmpty) {
          return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelAliasGroup?> byId(int id, [Transaction? txn]) async {
    Future<ModelAliasGroup?> select(Transaction txn) async {
      final rows = await txn.query(TableAliasGroup.table,
          columns: TableAliasGroup.columns,
          where: '${TableAliasGroup.primaryKey.column} = ?',
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

  static Future<List<ModelAliasGroup>> byIdList(List<int> ids) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableAliasGroup.table,
            columns: TableAliasGroup.columns,
            where:
                '${TableAliasGroup.primaryKey.column} IN (${List.filled(ids.length, '?').join(', ')})',
            whereArgs: ids);
      },
    );
    List<ModelAliasGroup> models = [];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('byIdList iter through rows: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelAliasGroup>> _search(String text,
      {int offset = 0, int limit = 50}) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableAliasGroup.table,
            where:
                '${TableAliasGroup.title} like ? OR ${TableAliasGroup.description} like ?',
            whereArgs: [text, text],
            offset: offset,
            limit: limit);
      },
    );
    var models = <ModelAliasGroup>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelAliasGroup>> select(
      {int offset = 0,
      int limit = 50,
      bool activated = true,
      String search = ''}) async {
    if (search.isNotEmpty) {
      return await ModelAliasGroup._search(search,
          offset: offset, limit: limit);
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableAliasGroup.table,
            columns: TableAliasGroup.columns,
            where: '${TableAliasGroup.isActive.column} = ?',
            whereArgs: [TypeAdapter.serializeBool(activated)],
            limit: limit,
            offset: offset,
            orderBy: TableAliasGroup.title.column);
      },
    );
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
  }

  Future<ModelAliasGroup> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableAliasGroup.primaryKey.column);
    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableAliasGroup.table, map);
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
        return await txn.update(TableAliasGroup.table, toMap(),
            where: '${TableAliasGroup.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  Future<List<int>> aliasIds() async {
    var col = TableAliasAliasGroup.idAlias.column;
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableAliasAliasGroup.table,
          columns: [col],
          where: '${TableAliasAliasGroup.idAliasGroup.column} = ?',
          whereArgs: [id]);
    });
    return rows.map((e) => TypeAdapter.deserializeInt(e[col])).toList();
  }

  Future<int> aliasCount() async {
    return await DB.execute<int>((txn) async {
      var col = 'ct';
      final rows = await txn.query(TableAliasAliasGroup.table,
          columns: ['count(*) as $col'],
          where: '${TableAliasAliasGroup.idAliasGroup.column} = ?',
          whereArgs: [id]);
      return TypeAdapter.deserializeInt(rows.firstOrNull?[col]);
    });
  }

  /// select a list of distinct Groups from a List of Alias IDs
  static Future<List<ModelAliasGroup>> groups(
      List<ModelAlias> aliasModels) async {
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      var ids = aliasModels
          .map(
            (e) => e.id,
          )
          .toList();
      var q = '''
SELECT ${TableAliasGroup.columns.join(', ')} FROM ${TableAliasAliasGroup.table}
LEFT JOIN ${TableAliasGroup.table} ON ${TableAliasAliasGroup.idAliasGroup} = ${TableAliasGroup.primaryKey}
WHERE ${TableAliasAliasGroup.idAlias} IN (${List.filled(ids.length, '?').join(', ')})
GROUP by  ${TableAliasGroup.primaryKey}
ORDER BY ${TableAliasGroup.primaryKey}
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
        for (var column in TableAliasGroup.calendarFields()) {
          fields[column.column] = '';
        }
        await txn.update(TableAliasGroup.table, fields, where: '1');
      },
    );
    await Cache.backgroundCalendarLastEventIds.save<List<CalendarEventId>>([]);
  }

  ModelAliasGroup clone() {
    return fromMap(toMap());
  }
}
