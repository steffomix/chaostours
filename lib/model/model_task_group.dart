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

import 'package:chaostours/database/database.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_group.dart';
import 'package:sqflite/sqflite.dart';

class ModelTaskGroup implements ModelGroup {
  static final Logger logger = Logger.logger<ModelTaskGroup>();
  int _id = 0;
  @override
  int get id => _id;
  bool isActive = true;
  bool isSelectable = true;
  bool isPreselected = false;
  String sortOrder = '';
  @override
  String title = '';
  @override
  String description = '';

  ModelTaskGroup(
      {this.isActive = true,
      this.isSelectable = true,
      this.isPreselected = false,
      this.sortOrder = '',
      this.title = '',
      this.description = ''});

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableTaskGroup.primaryKey.column: id,
      TableTaskGroup.isActive.column: TypeAdapter.serializeBool(isActive),
      TableTaskGroup.isSelectable.column:
          TypeAdapter.serializeBool(isSelectable),
      TableTaskGroup.isPreselected.column:
          TypeAdapter.serializeBool(isPreselected),
      TableTaskGroup.sortOrder.column: sortOrder,
      TableTaskGroup.title.column: title,
      TableTaskGroup.description.column: description
    };
  }

  static ModelTaskGroup fromMap(Map<String, Object?> map) {
    var model = ModelTaskGroup(
        isActive:
            TypeAdapter.deserializeBool(map[TableTaskGroup.isActive.column]),
        isSelectable: TypeAdapter.deserializeBool(
            map[TableTaskGroup.isSelectable.column]),
        isPreselected: TypeAdapter.deserializeBool(
            map[TableTaskGroup.isPreselected.column]),
        sortOrder:
            TypeAdapter.deserializeString(map[TableTaskGroup.sortOrder.column]),
        title: TypeAdapter.deserializeString(map[TableTaskGroup.title.column]),
        description: TypeAdapter.deserializeString(
            map[TableTaskGroup.description.column]));
    model._id =
        TypeAdapter.deserializeInt(map[TableTaskGroup.primaryKey.column]);
    return model;
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn
            .query(TableTaskGroup.table, columns: ['count(*) as $col']);

        if (rows.isNotEmpty) {
          return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  Future<int> taskCount() async {
    return await DB.execute<int>((txn) async {
      var col = 'ct';
      final rows = await txn.query(TableTaskTaskGroup.table,
          columns: ['count(*) as $col'],
          where: '${TableTaskTaskGroup.idTaskGroup.column} = ?',
          whereArgs: [id]);
      return TypeAdapter.deserializeInt(rows.firstOrNull?[col]);
    });
  }

  static Future<ModelTaskGroup?> byId(int id, [Transaction? txn]) async {
    Future<ModelTaskGroup?> select(Transaction txn) async {
      final rows = await txn.query(TableTaskGroup.table,
          columns: TableTaskGroup.columns,
          where: '${TableTaskGroup.primaryKey.column} = ?',
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

  static Future<List<ModelTaskGroup>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelTaskGroup>[];
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTaskGroup.table,
            columns: TableTaskGroup.columns,
            where:
                '${TableTaskGroup.primaryKey.column} IN (${List.filled(ids.length, '?').join(', ')})',
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
  static Future<List<ModelTaskGroup>> _search(String text,
      {int offset = 0, int limit = 50}) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableTaskGroup.table,
            where:
                '${TableTaskGroup.title} like ? OR ${TableTaskGroup.description} like ?',
            whereArgs: [text, text],
            limit: limit,
            offset: offset);
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
      {int offset = 0,
      int limit = 50,
      bool activated = true,
      String search = ''}) async {
    if (search.isNotEmpty) {
      return await ModelTaskGroup._search(search, offset: offset, limit: limit);
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTaskGroup.table,
            columns: TableTaskGroup.columns,
            where: '${TableTaskGroup.isActive.column} = ?',
            whereArgs: [TypeAdapter.serializeBool(activated)],
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
  Future<ModelTaskGroup> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableTaskGroup.primaryKey.column);
    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableTaskGroup.table, map);
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
        return await txn.update(TableTaskGroup.table, toMap(),
            where: '${TableTaskGroup.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  Future<List<int>> taskIds() async {
    var col = TableTaskTaskGroup.idTask.column;
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableTaskTaskGroup.table,
          columns: [col],
          where: '${TableTaskTaskGroup.idTaskGroup.column} = ?',
          whereArgs: [id]);
    });
    return rows.map((e) => TypeAdapter.deserializeInt(e[col])).toList();
  }

/* 
  /// select a list of distinct Groups from a List of Task IDs
  static Future<List<ModelTaskGroup>> groups(List<ModelTask> models) async {
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      var ids = models
          .map(
            (e) => e.id,
          )
          .toList();
      var q = '''
SELECT ${TableTaskGroup.columns.join(', ')} FROM ${TableTaskTaskGroup.table}
LEFT JOIN ${TableTaskGroup.table} ON ${TableTaskTaskGroup.idTaskGroup} = ${TableTaskGroup.primaryKey}
WHERE ${TableTaskTaskGroup.idTask} IN (${List.filled(ids.length, '?').join(', ')})
GROUP by  ${TableTaskGroup.primaryKey}
ORDER BY ${TableTaskGroup.primaryKey}
''';
      return await txn.rawQuery(q, ids);
    });
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
  }
 */
  ModelTaskGroup clone() {
    return fromMap(toMap());
  }
}
