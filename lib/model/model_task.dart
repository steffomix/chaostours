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

import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/model/model.dart';
import 'package:sqflite/sqflite.dart';
//
import 'package:chaostours/database/database.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_task_group.dart';

class ModelTask implements Model {
  static Logger logger = Logger.logger<ModelTask>();

  int _id = 0;
  @override
  int get id => _id;
  bool isActive;
  bool isSelectable = true;
  bool isPreselected = false;
  String sortOrder;
  @override
  String title;
  @override
  String description;
  @override
  String trackpointNotes = '';

  ModelTask(
      {this.sortOrder = '',
      this.isActive = true,
      this.isSelectable = true,
      this.isPreselected = false,
      this.title = '',
      this.description = ''});

  static ModelTask fromMap(Map<String, Object?> map) {
    var model = ModelTask(
        isActive: TypeAdapter.deserializeBool(map[TableTask.isActive.column]),
        isSelectable:
            TypeAdapter.deserializeBool(map[TableTask.isSelectable.column]),
        isPreselected:
            TypeAdapter.deserializeBool(map[TableTask.isPreselected.column]),
        sortOrder:
            TypeAdapter.deserializeString(map[TableTask.sortOrder.column]),
        title: TypeAdapter.deserializeString(map[TableTask.title.column]),
        description:
            TypeAdapter.deserializeString(map[TableTask.description.column]));
    model._id = TypeAdapter.deserializeInt(map[TableTask.primaryKey.column]);
    return model;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableTask.primaryKey.column: id,
      TableTask.isActive.column: TypeAdapter.serializeBool(isActive),
      TableTask.isSelectable.column: TypeAdapter.serializeBool(isSelectable),
      TableTask.isPreselected.column: TypeAdapter.serializeBool(isPreselected),
      TableTask.sortOrder.column: sortOrder,
      TableTask.title.column: title,
      TableTask.description.column: description
    };
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows =
            await txn.query(TableTask.table, columns: ['count(*) as $col']);

        if (rows.isNotEmpty) {
          return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelTask?> byId(int id, [Transaction? txn]) async {
    Future<ModelTask?> select(Transaction txn) async {
      final rows = await txn.query(TableTask.table,
          columns: TableTask.columns,
          where: '${TableTask.primaryKey.column} = ?',
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

  static Future<List<ModelTask>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelTask>[];
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTask.table,
            columns: TableTask.columns,
            where:
                '${TableTask.primaryKey.column} IN (${List.filled(ids.length, '?').join(', ')})',
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

  /// select ALL groups from this location for checkbox selection.
  Future<List<int>> groupIds() async {
    var col = TableTaskTaskGroup.idTaskGroup.column;
    final ids = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableTaskTaskGroup.table,
          columns: [col],
          where: '${TableTaskTaskGroup.idTask.column} = ?',
          whereArgs: [id]);
    });
    if (ids.isEmpty) {
      return <int>[];
    }
    return ids.map((e) => TypeAdapter.deserializeInt(e[col])).toList();
  }

  Future<int> addGroup(ModelTaskGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.insert(TableTaskTaskGroup.table, {
          TableTaskTaskGroup.idTask.column: id,
          TableTaskTaskGroup.idTaskGroup.column: group.id
        });
        return c;
      } catch (e) {
        logger.warn('addGroup: $e');
        return 0;
      }
    });
  }

  Future<int> removeGroup(ModelTaskGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.delete(
          TableTaskTaskGroup.table,
          where:
              '${TableTaskTaskGroup.idTask.column} = ? AND ${TableTaskTaskGroup.idTaskGroup.column} = ?',
          whereArgs: [id, group.id],
        );
        return c;
      } catch (e) {
        logger.warn('addGroup: $e');
        return 0;
      }
    });
  }

  /// transforms text into %text%
  static Future<List<ModelTask>> _search(String text,
      {int limit = 50, int offset = 0, bool selectDeleted = true}) async {
    text = '%$text%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableTask.table,
            where: selectDeleted
                ? '${TableTask.title} like ? OR ${TableTask.description} like ?'
                : '(${TableTask.title} like ? OR ${TableTask.description} like ?) AND ${TableTask.isActive.column} = ?',
            whereArgs: selectDeleted
                ? [text, text]
                : [text, text, TypeAdapter.serializeBool(true)],
            orderBy: '${TableTask.isActive.column}, ${TableTask.title.column}',
            limit: limit,
            offset: offset);
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
      {int offset = 0,
      int limit = 50,
      bool useSortOrder = false,
      bool activated = true,
      String search = ''}) async {
    if (search.isNotEmpty) {
      return await ModelTask._search(search, offset: offset, limit: limit);
    }

    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableTask.table,
            columns: TableTask.columns,
            where: '${TableTask.isActive.column} = ?',
            whereArgs: [TypeAdapter.serializeBool(activated)],
            orderBy: '${TableTask.sortOrder.column}, ${TableTask.title.column}',
            limit: limit,
            offset: offset);
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
  Future<ModelTask> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableTask.primaryKey.column);
    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableTask.table, map);
        await txn.insert(TableTaskTaskGroup.table, {
          TableTaskTaskGroup.idTask.column: _id,
          TableTaskTaskGroup.idTaskGroup.column: 1
        });
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
        return await txn.update(TableTask.table, toMap(),
            where: '${TableTask.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  static Future<void> resetSortOrder() async {
    await DB.execute(
      (Transaction txn) async {
        await txn.rawQuery(
            'UPDATE ${TableTask.table} SET ${TableTask.sortOrder.column} = ${TableTask.primaryKey.column} WHERE 1');
      },
    );
  }

  static Future<List<ModelTask>> preselected() async {
    const nullsort = 'nullsort';
    var columns = [...TableTask.columns];
    columns.add(
        '''CASE WHEN ${TableTask.sortOrder} IS '' THEN 2 ELSE 1 END AS $nullsort''');

    final rows = await DB.execute((txn) async {
      final q = '''
      SELECT ${columns.join(', ')} FROM ${TableTask.table}
      LEFT JOIN ${TableTaskTaskGroup.table} ON ${TableTaskTaskGroup.idTask} = ${TableTask.id}
      LEFT JOIN ${TableTaskGroup.table} ON ${TableTaskTaskGroup.idTaskGroup} = ${TableTaskGroup.id} 
      WHERE (${TableTaskGroup.isActive} = ? AND ${TableTaskGroup.isPreselected} = ?) 
      OR (${TableTask.isActive} = ? AND ${TableTask.isPreselected} = ?)
      GROUP BY ${TableTask.id}
      ORDER BY $nullsort, ${TableTask.sortOrder}, ${TableTask.title}
''';
      return await txn.rawQuery(
          q, List.filled(4, TypeAdapter.serializeBool(true)));
    });
    return rows.map((e) => fromMap(e)).toList();
  }

  static Future<List<ModelTask>> selectable() async {
    const nullsort = 'nullsort';
    var columns = [...TableTask.columns];
    columns.add(
        '''CASE WHEN ${TableTask.sortOrder} IS '' THEN 2 ELSE 1 END AS $nullsort''');

    final rows = await DB.execute((txn) async {
      final q = '''
      SELECT ${columns.join(', ')} FROM ${TableTask.table}
      LEFT JOIN ${TableTaskTaskGroup.table} ON ${TableTaskTaskGroup.idTask} = ${TableTask.id}
      LEFT JOIN ${TableTaskGroup.table} ON ${TableTaskTaskGroup.idTaskGroup} = ${TableTaskGroup.id}
      WHERE 
        (${TableTaskGroup.isActive} = ? AND (${TableTaskGroup.isPreselected} = ? OR ${TableTaskGroup.isSelectable} = ?))
        OR (${TableTask.isActive} = ?   AND (${TableTask.isPreselected} = ?      OR  ${TableTask.isSelectable} = ?))
      
      GROUP BY ${TableTask.id}
      ORDER BY $nullsort, ${TableTask.sortOrder}, ${TableTask.title}
''';
      return await txn.rawQuery(
          q, List.filled(6, TypeAdapter.serializeBool(true)));
    });
    return rows.map((e) => fromMap(e)).toList();
  }

  ModelTask clone() {
    return fromMap(toMap());
  }
}
