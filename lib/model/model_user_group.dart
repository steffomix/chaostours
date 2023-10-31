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
import 'package:chaostours/model/model_user.dart';
import 'package:sqflite/sqflite.dart';

class ModelUserGroup {
  static final Logger logger = Logger.logger<ModelUserGroup>();
  int _id = 0;
  int get id => _id;
  bool isActive = true;
  int sortOrder = 0;
  String title = '';
  String description = '';

  ModelUserGroup(
      {this.isActive = true,
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
    var model = ModelUserGroup(
        isActive: DB.parseBool(map[TableUserGroup.isActive.column]),
        sortOrder: DB.parseInt(map[TableUserGroup.sortOrder.column]),
        title: DB.parseString(map[TableUserGroup.title.column]),
        description: DB.parseString(map[TableUserGroup.description.column]));
    model._id = DB.parseInt(map[TableUserGroup.primaryKey.column]);
    return model;
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn
            .query(TableUserGroup.table, columns: ['count(*) as $col']);

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
                '${TableUserGroup.primaryKey.column} IN (${List.filled(ids.length, '?').join(', ')})',
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
  static Future<List<ModelUserGroup>> _search(String search,
      {int offset = 0, int limit = 50}) async {
    search = '%$search%';
    var rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableUserGroup.table,
            where:
                '${TableUserGroup.title} like ? OR ${TableUserGroup.description} like ?',
            whereArgs: [search, search]);
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
      {int offset = 0,
      int limit = 50,
      bool activated = true,
      String search = ''}) async {
    if (search.isNotEmpty) {
      return await ModelUserGroup._search(search, offset: offset, limit: limit);
    }

    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableUserGroup.table,
            columns: TableUserGroup.columns,
            where: '${TableUserGroup.isActive.column} = ?',
            whereArgs: [activated],
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

  Future<ModelUserGroup> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableUserGroup.primaryKey.column);
    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableUserGroup.table, map);
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
        return await txn.update(TableUserGroup.table, toMap(),
            where: '${TableUserGroup.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  /// select ALL groups from this User for checkbox selection.
  Future<List<int>> userIds() async {
    var col = TableUserUserGroup.idUser.column;
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableUserUserGroup.table,
          columns: [col],
          where: '${TableUserUserGroup.idUserGroup.column} = ?',
          whereArgs: [id]);
    });
    return rows.map((e) => DB.parseInt(e[col])).toList();
  }

  /// select a list of distinct Groups from a List of User IDs
  static Future<List<ModelUserGroup>> groups(List<ModelUser> models) async {
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      var ids = models
          .map(
            (e) => e.id,
          )
          .toList();
      var q = '''
SELECT ${TableUserGroup.columns.join(', ')} FROM ${TableUserUserGroup.table}
LEFT JOIN ${TableUserGroup.table} ON ${TableUserUserGroup.idUserGroup} = ${TableUserGroup.primaryKey}
WHERE ${TableUserUserGroup.idUser} IN (${List.filled(ids.length, '?').join(', ')})
GROUP by  ${TableUserGroup.primaryKey}
ORDER BY ${TableUserGroup.primaryKey}
''';
      return await txn.rawQuery(q, ids);
    });
    return rows
        .map(
          (e) => fromMap(e),
        )
        .toList();
  }

  ModelUserGroup clone() {
    return fromMap(toMap());
  }
}
