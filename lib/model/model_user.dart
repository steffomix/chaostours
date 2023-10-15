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
import 'package:chaostours/database.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/logger.dart';
import 'package:sqflite/sqflite.dart';

class ModelUser extends Model {
  static Logger logger = Logger.logger<ModelUser>();

  int groupId = 1;
  int sortOrder = 0;
  bool isActive = true;
  String title = '';
  String description = '';
  String phone = '';
  String address = '';

  ModelUser(
      {super.id = 0,
      this.groupId = 1,
      this.sortOrder = 0,
      this.isActive = true,
      this.title = '',
      this.description = '',
      this.phone = '',
      this.address = ''});

  static ModelUser fromMap(Map<String, Object?> map) {
    return ModelUser(
        id: DB.parseInt(map[TableUser.primaryKey.column]),
        groupId: DB.parseInt(map[TableUser.idUserGroup.column], fallback: 1),
        isActive: DB.parseBool(map[TableUser.isActive.column]),
        sortOrder: DB.parseInt(map[TableUser.sortOrder.column]),
        title: DB.parseString(map[TableUser.title.column]),
        description: DB.parseString(map[TableUser.description.column]));
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableUser.primaryKey.column: id,
      TableUser.idUserGroup.column: groupId,
      TableUser.isActive.column: DB.boolToInt(isActive),
      TableUser.sortOrder.column: sortOrder,
      TableUser.title.column: title,
      TableUser.description.column: description
    };
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows = await txn.query(TableUser.table,
            columns: ['count(*) as $col'],
            groupBy: TableUser.primaryKey.column);

        if (rows.isNotEmpty) {
          return DB.parseInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelUser?> byId(int id) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableUser.table,
            columns: TableUser.columns,
            where: '${TableUser.primaryKey.column} = ?',
            whereArgs: [id]);
      },
    );
    if (rows.isNotEmpty) {
      return fromMap(rows.first);
    }
    return null;
  }

  static Future<List<ModelUser>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelUser>[];
    }
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableUser.table,
            columns: TableUser.columns,
            where:
                '${TableUser.primaryKey.column} IN ${List.filled(ids.length, '?').join('?')}',
            whereArgs: ids);
      },
    );
    List<ModelUser> models = [];
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
  static Future<List<ModelUser>> search(String text,
      {int limit = 50, int offset = 0}) async {
    text = '%$text%';
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableUser.table,
            where:
                '${TableUser.title} like ? OR ${TableUser.description} like ?',
            whereArgs: [text, text],
            limit: limit,
            offset: offset);
      },
    );
    List<ModelUser> models = [];
    for (var row in rows) {
      try {
        models.add(fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelUser>> select(
      {int limit = 50, int offset = 0}) async {
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(TableUser.table,
            columns: TableUser.columns,
            limit: limit,
            offset: offset,
            orderBy: TableUser.primaryKey.column);
      },
    );
    List<ModelUser> models = [];
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
  static Future<ModelUser> insert(ModelUser model) async {
    var map = model.toMap();
    map.removeWhere((key, value) => key == TableUser.primaryKey.column);
    int id = await DB.execute<int>(
      (Transaction txn) async {
        return await txn.insert(TableUser.table, map);
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
        return await txn.update(TableUser.table, toMap(),
            where: '${TableUser.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  ModelUser clone() {
    return fromMap(toMap());
  }
}
