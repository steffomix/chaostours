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
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:sqflite/sqflite.dart';

class ModelTaskGroup extends Model {
  static final Logger logger = Logger.logger<ModelTaskGroup>();

  bool isActive = true;
  AliasVisibility visibility = AliasVisibility.public;
  int sortOrder = 0;
  String title = '';
  String description = '';

  ModelTaskGroup(
      {super.id = 0,
      this.isActive = true,
      this.visibility = AliasVisibility.public,
      this.sortOrder = 0,
      this.title = '',
      this.description = ''});

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableTaskGroup.primaryKey.column: id,
      TableTaskGroup.isActive.column: DB.boolToInt(isActive),
      TableTaskGroup.sortOrder.column: sortOrder,
      TableTaskGroup.title.column: title,
      TableTaskGroup.description.column: description
    };
  }

  static ModelTaskGroup fromMap(Map<String, Object?> map) {
    return ModelTaskGroup(
        id: DB.parseInt(map[TableTaskGroup.primaryKey.column]),
        isActive: DB.parseBool(map[TableTaskGroup.isActive.column]),
        sortOrder: DB.parseInt(map[TableTaskGroup.sortOrder.column]),
        title: DB.parseString(map[TableTaskGroup.title.column]),
        description: DB.parseString(map[TableTaskGroup.description.column]));
  }

  static Future<ModelTaskGroup?> byId(int id) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTaskGroup.table,
            columns: TableTaskGroup.columns,
            where: '${TableTaskGroup.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return fromMap(rows.first);
    }
    return null;
  }

  static Future<List<ModelTaskGroup>> byIdList(List<int> ids) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTaskGroup.table,
            columns: TableTaskGroup.columns,
            where:
                '${TableTaskGroup.primaryKey.column} IN ${List.filled(ids.length, '?').join('?')}',
            whereArgs: ids);
      },
    );
    List<ModelTaskGroup> models = [];
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
  static Future<List<ModelTaskGroup>> search(String text) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableTaskGroup.table,
            where:
                '${TableTaskGroup.title} like ? OR ${TableTaskGroup.description} like ?',
            whereArgs: [text, text]);
      },
    );
    var models = <ModelTaskGroup>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelTaskGroup>> select(
      {int limit = 50, int offset = 0}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTaskGroup.table,
            columns: TableTaskGroup.columns,
            limit: limit,
            offset: offset,
            orderBy: TableTaskGroup.primaryKey.column);
      },
    );
    List<ModelTaskGroup> models = [];
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
  static Future<ModelTaskGroup> insert(ModelTaskGroup model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableTaskGroup.primaryKey.column);
    int id = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.insert(TableTaskGroup.table, map);
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
        return await txn.update(TableTaskGroup.table, toMap(),
            where: '${TableTaskGroup.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  ModelTaskGroup clone() {
    return fromMap(toMap());
  }
}
