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

import 'package:chaostours/database.dart';
import 'package:chaostours/app_logger.dart';
import 'package:chaostours/model/model.dart';
import 'package:sqflite/sqflite.dart';

class ModelUserGroup extends Model {
  static final AppLogger logger = AppLogger.logger<ModelUserGroup>();

  bool isActive = true;
  int sortOrder = 0;
  String title = '';
  String description = '';

  ModelUserGroup(
      {super.id = 0,
      this.isActive = true,
      this.sortOrder = 0,
      this.title = '',
      this.description = ''});

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableUserGroup.primaryKey.column: id,
      TableUserGroup.isActive.column: DB.boolToInt(isActive),
      TableUserGroup.sortOrder.column: sortOrder,
      TableUserGroup.title.column: title,
      TableUserGroup.description.column: description
    };
  }

  static ModelUserGroup fromMap(Map<String, Object?> map) {
    return ModelUserGroup(
        id: DB.parseInt(map[TableUserGroup.primaryKey.column]),
        isActive: DB.parseBool(map[TableUserGroup.isActive.column]),
        sortOrder: DB.parseInt(map[TableUserGroup.sortOrder.column]),
        title: DB.parseString(map[TableUserGroup.title.column]),
        description: DB.parseString(map[TableUserGroup.description.column]));
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn.query(TableUserGroup.table,
            columns: ['count(*) as $col'],
            groupBy: TableUserGroup.primaryKey.column);

        if (rows.isNotEmpty) {
          return DB.parseInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelUserGroup?> byId(int id) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableUserGroup.table,
            columns: TableUserGroup.columns,
            where: '${TableUserGroup.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return fromMap(rows.first);
    }
    return null;
  }

  static Future<List<ModelUserGroup>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelUserGroup>[];
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableUserGroup.table,
            columns: TableUserGroup.columns,
            where:
                '${TableUserGroup.primaryKey.column} IN ${List.filled(ids.length, '?').join('?')}',
            whereArgs: ids);
      },
    );
    List<ModelUserGroup> models = [];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('byIdList iter through rows: $e', stk);
      }
    }
    return models;
  }

  /// transforms text into %text%
  static Future<List<ModelUserGroup>> search(String text) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableUserGroup.table,
            where:
                '${TableUserGroup.title} like ? OR ${TableUserGroup.description} like ?',
            whereArgs: [text, text]);
      },
    );
    var models = <ModelUserGroup>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelUserGroup>> select(
      {int limit = 50, int offset = 0}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableUserGroup.table,
            columns: TableUserGroup.columns,
            limit: limit,
            offset: offset,
            orderBy: TableUserGroup.primaryKey.column);
      },
    );
    List<ModelUserGroup> models = [];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('select _fromMap: $e', stk);
      }
    }
    return models;
  }

  /// returns task id
  static Future<ModelUserGroup> insert(ModelUserGroup model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableUserGroup.primaryKey.column);
    int id = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.insert(TableUserGroup.table, map);
      },
    );
    model.id = id;
    return model;
  }

  Future<int> update() async {
    if (id <= 0) {
      throw ('update model "$title" has no id');
    }
    var count = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.update(TableUserGroup.table, toMap(),
            where: '${TableUserGroup.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  ModelUserGroup clone() {
    return fromMap(toMap());
  }
}
