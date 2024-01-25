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
import 'package:chaostours/model/model_user_group.dart';

class ModelUser implements Model {
  static Logger logger = Logger.logger<ModelUser>();

  int _id = 0;
  @override
  int get id => _id;
  String sortOrder;
  bool isActive = true;
  bool isSelectable = true;
  bool isPreselected = false;
  @override
  String title = '';
  @override
  String description = '';
  String phone = '';
  String address = '';
  @override
  String trackpointNotes = '';

  ModelUser(
      {this.sortOrder = '',
      this.isActive = true,
      this.isSelectable = true,
      this.isPreselected = false,
      this.title = '',
      this.description = '',
      this.phone = '',
      this.address = ''});

  static ModelUser fromMap(Map<String, Object?> map) {
    var model = ModelUser(
      isActive: TypeAdapter.deserializeBool(map[TableUser.isActive.column]),
      isSelectable:
          TypeAdapter.deserializeBool(map[TableUser.isSelectable.column]),
      isPreselected:
          TypeAdapter.deserializeBool(map[TableUser.isPreselected.column]),
      sortOrder: TypeAdapter.deserializeString(map[TableUser.sortOrder.column]),
      title: TypeAdapter.deserializeString(map[TableUser.title.column]),
      description:
          TypeAdapter.deserializeString(map[TableUser.description.column]),
      phone: TypeAdapter.deserializeString(map[TableUser.phone.column]),
      address: TypeAdapter.deserializeString(map[TableUser.address.column]),
    );
    model._id = TypeAdapter.deserializeInt(map[TableUser.primaryKey.column]);
    return model;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      TableUser.primaryKey.column: id,
      TableUser.isActive.column: TypeAdapter.serializeBool(isActive),
      TableUser.isSelectable.column: TypeAdapter.serializeBool(isSelectable),
      TableUser.isPreselected.column: TypeAdapter.serializeBool(isPreselected),
      TableUser.sortOrder.column: sortOrder,
      TableUser.title.column: title,
      TableUser.description.column: description,
      TableUser.phone.column: phone,
      TableUser.address.column: address
    };
  }

  static Future<int> count() async {
    return await DB.execute<int>(
      (Transaction txn) async {
        const col = 'ct';
        final rows =
            await txn.query(TableUser.table, columns: ['count(*) as $col']);

        if (rows.isNotEmpty) {
          return TypeAdapter.deserializeInt(rows.first[col], fallback: 0);
        } else {
          return 0;
        }
      },
    );
  }

  static Future<ModelUser?> byId(int id, [Transaction? txn]) async {
    Future<ModelUser?> select(Transaction txn) async {
      final rows = await txn.query(TableUser.table,
          columns: TableUser.columns,
          where: '${TableUser.primaryKey.column} = ?',
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

  static Future<List<ModelUser>> byIdList(List<int> ids) async {
    if (ids.isEmpty) {
      return <ModelUser>[];
    }
    final rows = await DB.execute(
      (Transaction txn) async {
        return await txn.query(TableUser.table,
            columns: TableUser.columns,
            where:
                '${TableUser.primaryKey.column} IN (${List.filled(ids.length, '?').join(', ')})',
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

  /// select ALL groups from this location for checkbox selection.
  Future<List<int>> groupIds() async {
    var col = TableUserUserGroup.idUserGroup.column;
    final ids = await DB.execute<List<Map<String, Object?>>>((txn) async {
      return await txn.query(TableUserUserGroup.table,
          columns: [col],
          where: '${TableUserUserGroup.idUser.column} = ?',
          whereArgs: [id]);
    });
    if (ids.isEmpty) {
      return <int>[];
    }
    return ids.map((e) => TypeAdapter.deserializeInt(e[col])).toList();
  }

  Future<int> addGroup(ModelUserGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.insert(TableUserUserGroup.table, {
          TableUserUserGroup.idUser.column: id,
          TableUserUserGroup.idUserGroup.column: group.id
        });
        return c;
      } catch (e) {
        logger.warn('addGroup: $e');
        return 0;
      }
    });
  }

  Future<int> removeGroup(ModelUserGroup group) async {
    return await DB.execute<int>((txn) async {
      try {
        var c = await txn.delete(
          TableUserUserGroup.table,
          where:
              '${TableUserUserGroup.idUser.column} = ? AND ${TableUserUserGroup.idUserGroup.column} = ?',
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
  static Future<List<ModelUser>> _search(String text,
      {int offset = 0, int limit = 50, selectDeleted = true}) async {
    text = '%$text%';
    final rows = await DB.execute<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableUser.table,
            where: selectDeleted
                ? '${TableUser.title} like ? OR ${TableUser.description} like ?'
                : '(${TableUser.title} like ? OR ${TableUser.description} like ?) AND ${TableUser.isActive.column} = ?',
            whereArgs: selectDeleted
                ? [text, text]
                : [text, text, TypeAdapter.serializeBool(true)],
            orderBy: '${TableUser.isActive.column}, ${TableUser.title.column}',
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
      {int offset = 0,
      int limit = 50,
      bool activated = true,
      bool useSortOrder = false,
      String search = ''}) async {
    if (search.isNotEmpty) {
      return await ModelUser._search(search, offset: offset, limit: limit);
    }

    final rows = await DB.execute<List<Map<String, Object?>>>(
      (Transaction txn) async {
        return await txn.query(
          TableUser.table,
          columns: TableUser.columns,
          where: '${TableUser.isActive.column} = ?',
          whereArgs: [TypeAdapter.serializeBool(activated)],
          orderBy: '${TableUser.sortOrder.column}, ${TableUser.title.column}',
          limit: limit,
          offset: offset,
        );
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

  /// returns user id
  Future<ModelUser> insert() async {
    var map = toMap();
    map.removeWhere((key, value) => key == TableUser.primaryKey.column);
    await DB.execute(
      (Transaction txn) async {
        _id = await txn.insert(TableUser.table, map);
        await txn.insert(TableUserUserGroup.table, {
          TableUserUserGroup.idUser.column: _id,
          TableUserUserGroup.idUserGroup.column: 1
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
        return await txn.update(TableUser.table, toMap(),
            where: '${TableUser.primaryKey.column} = ?', whereArgs: [id]);
      },
    );
    return count;
  }

  static Future<void> resetSortOrder() async {
    await DB.execute(
      (Transaction txn) async {
        await txn.rawQuery(
            'UPDATE ${TableUser.table} SET ${TableUser.sortOrder.column} = ${TableUser.primaryKey.column} WHERE 1');
      },
    );
  }

  static Future<List<ModelUser>> preselected() async {
    const nullsort = 'nullsort';
    var columns = [...TableUser.columns];
    columns.add(
        '''CASE WHEN ${TableUser.sortOrder} IS '' THEN 2 ELSE 1 END AS $nullsort''');

    final rows = await DB.execute((txn) async {
      final q = '''
      SELECT ${columns.join(', ')} FROM ${TableUser.table}
      LEFT JOIN ${TableUserUserGroup.table} ON ${TableUserUserGroup.idUser} = ${TableUser.id}
      LEFT JOIN ${TableUserGroup.table} ON ${TableUserUserGroup.idUserGroup} = ${TableUserGroup.id}
      WHERE (${TableUserGroup.isActive} = ? AND  ${TableUserGroup.isPreselected} = ?)
      OR (${TableUser.isActive} = ? AND ${TableUser.isPreselected} = ?)
      GROUP BY ${TableUser.id}
      ORDER BY $nullsort, ${TableUser.sortOrder}, ${TableUser.title}
''';

      return await txn.rawQuery(
          q, List.filled(3, TypeAdapter.serializeBool(true)));
    });
    return rows.map((e) => fromMap(e)).toList();
  }

  static Future<List<ModelUser>> selectable() async {
    const nullsort = 'nullsort';
    var columns = [...TableUser.columns];
    columns.add(
        '''CASE WHEN ${TableUser.sortOrder} IS '' THEN 2 ELSE 1 END AS $nullsort''');

    final rows = await DB.execute((txn) async {
      final q = '''
      SELECT ${columns.join(', ')} FROM ${TableUser.table}
      LEFT JOIN ${TableUserUserGroup.table} ON ${TableUserUserGroup.idUser} = ${TableUser.id}
      LEFT JOIN ${TableUserGroup.table} ON ${TableUserUserGroup.idUserGroup} = ${TableUserGroup.id}
      WHERE (${TableUserGroup.isActive} = ? AND (${TableUserGroup.isPreselected} = ? OR ${TableUserGroup.isSelectable} = ?))
      OR (${TableUser.isActive} = ?   AND (${TableUser.isPreselected} = ?      OR  ${TableUser.isSelectable} = ?))
      GROUP BY ${TableUser.id}
      ORDER BY $nullsort, ${TableUser.sortOrder}, ${TableUser.title}
''';
      return await txn.rawQuery(
          q, List.filled(6, TypeAdapter.serializeBool(true)));
    });
    return rows.map((e) => fromMap(e)).toList();
  }

  ModelUser clone() {
    return fromMap(toMap());
  }
}
