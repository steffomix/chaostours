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
import 'package:chaostours/model/model_alias.dart';
import 'package:sqflite/sqflite.dart';

class ModelAliasGroup {
  static final Logger logger = Logger.logger<ModelAliasGroup>();
  int _id = 0;
  int get id => _id;
  bool isActive = true;
  String idCalendar = '';
  AliasVisibility visibility = AliasVisibility.public;
  String title = '';
  String description = '';

  ModelAliasGroup(
      {this.idCalendar = '',
      this.isActive = true,
      this.visibility = AliasVisibility.public,
      this.title = '',
      this.description = ''});

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableAliasGroup.primaryKey.column: id,
      TableAliasGroup.idCalendar.column: idCalendar,
      TableAliasGroup.isActive.column: DB.boolToInt(isActive),
      TableAliasGroup.visibility.column: visibility.value,
      TableAliasGroup.title.column: title,
      TableAliasGroup.description.column: description
    };
  }

  static ModelAliasGroup fromMap(Map<String, Object?> map) {
    var model = ModelAliasGroup(
        idCalendar: DB.parseString(map[TableAliasGroup.idCalendar.column]),
        isActive: DB.parseBool(map[TableAliasGroup.isActive.column]),
        visibility:
            AliasVisibility.byId(map[TableAliasGroup.visibility.column]),
        title: DB.parseString(map[TableAliasGroup.title.column]),
        description: DB.parseString(map[TableAliasGroup.description.column]));
    model._id = DB.parseInt(map[TableAliasGroup.primaryKey.column]);
    return model;
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn
            .query(TableAliasGroup.table, columns: ['count(*) as $col']);

        if (rows.isNotEmpty) {
          return DB.parseInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelAliasGroup?> byId(int id) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableAliasGroup.table,
            columns: TableAliasGroup.columns,
            where: '${TableAliasGroup.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return fromMap(rows.first);
    }
    return null;
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

  static Future<List<ModelAliasGroup>> search(String text,
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
      {int offset = 0, int limit = 50}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableAliasGroup.table,
            columns: TableAliasGroup.columns,
            limit: limit,
            offset: offset,
            orderBy: TableAliasGroup.primaryKey.column);
      },
    );
    List<ModelAliasGroup> models = [];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('select _fromMap: $e', stk);
      }
    }
    return models;
  }

  static Future<ModelAliasGroup> insert(ModelAliasGroup model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableAliasGroup.primaryKey.column);
    int id = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.insert(TableAliasGroup.table, map);
      },
    );
    model._id = id;
    return model;
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

  Future<List<ModelAlias>> children(
      {int offset = 0, int limit = 20, String search = ''}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>((txn) async {
      List<Object?> args = [];
      if (search.isNotEmpty) {
        var fields = [TableAlias.title, TableAlias.description];
        args.addAll(List.filled(fields.length, '%$search%'));
        search = ' AND (${fields.map(
              (e) => ' $e LIKE ? ',
            ).join(' OR ')})';
      }
      var q =
          '''SELECT ${TableAlias.columns.join(', ')} FROM ${TableAliasAliasGroup.table}
LEFT JOIN ${TableAlias.table} ON ${TableAliasAliasGroup.idAlias} = ${TableAlias.primaryKey}
WHERE ${TableAliasAliasGroup.idAliasGroup} = ? $search
ORDER BY ${TableAlias.title}
LIMIT ?
OFFSET ?  
''';
      return await txn.rawQuery(q, [id, ...args, limit, offset]);
    });
    return rows.map((e) => ModelAlias.fromMap(e)).toList();
  }

  ModelAliasGroup clone() {
    return fromMap(toMap());
  }
}
