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

//
import 'package:chaostours/app_database.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/app_logger.dart';
import 'package:sqflite/sqflite.dart';

class ModelTask extends Model {
  static AppLogger logger = AppLogger.logger<ModelTask>();

  int groupId = 1;
  int sortOrder = 0;
  bool isActive = true;
  String title = '';
  String description = '';

  ModelTask(
      {super.id = 0,
      this.groupId = 1,
      this.sortOrder = 0,
      this.isActive = true,
      this.title = '',
      this.description = ''});

  static ModelTask fromMap(Map<String, Object?> map) {
    return ModelTask(
        id: DB.parseInt(map[TableTask.primaryKey.column]),
        groupId: DB.parseInt(map[TableTask.idTaskGroup.column], fallback: 1),
        isActive: DB.parseBool(map[TableTask.isActive.column]),
        sortOrder: DB.parseInt(map[TableTask.sortOrder.column]),
        title: DB.parseString(map[TableTask.title.column]),
        description: DB.parseString(map[TableTask.description.column]));
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableTask.primaryKey.column: id,
      TableTask.idTaskGroup.column: groupId,
      TableTask.isActive.column: DB.boolToInt(isActive),
      TableTask.sortOrder.column: sortOrder,
      TableTask.title.column: title,
      TableTask.description.column: description
    };
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn.query(TableTask.table,
            columns: ['count(*) as $col'],
            groupBy: TableTask.primaryKey.column);

        if (rows.isNotEmpty) {
          return DB.parseInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelTask?> byId(int id) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTask.table,
            columns: TableTask.columns,
            where: '${TableTask.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return fromMap(rows.first);
    }
    return null;
  }

  static Future<List<ModelTask>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelTask>[];
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTask.table,
            columns: TableTask.columns,
            where:
                '${TableTask.primaryKey.column} IN ${List.filled(ids.length, '?').join('?')}',
            whereArgs: ids);
      },
    );
    List<ModelTask> models = [];
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
  static Future<List<ModelTask>> search(String text) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableTask.table,
            where:
                '${TableTask.title} like ? OR ${TableTask.description} like ?',
            whereArgs: [text, text]);
      },
    );
    var models = <ModelTask>[];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelTask>> select(
      {int limit = 50, int offset = 0}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTask.table,
            columns: TableTask.columns,
            limit: limit,
            offset: offset,
            orderBy: TableTask.primaryKey.column);
      },
    );
    List<ModelTask> models = [];
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
  static Future<ModelTask> insert(ModelTask model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableTask.primaryKey.column);
    int id = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.insert(TableTask.table, map);
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
        return await txn.update(TableTask.table, toMap(),
            where: '${TableTask.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  ModelTask clone() {
    return fromMap(toMap());
  }
}
