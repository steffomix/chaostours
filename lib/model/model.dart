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
import 'dart:convert';

import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/database/database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:chaostours/model/model_group.dart';

abstract class Model implements ModelGroup {
  String trackpointNotes = '';

  static final Logger logger = Logger.logger<Model>();
  static const String lineSep = '\n';

  static String toJson(Map<String, Object?> map) => jsonEncode(map);
  static Map<String, Object?> fromJson(String json) {
    var obj = jsonDecode(json);
    Map<String, Object?> map = {};
    if (obj is Map) {
      for (var k in obj.keys) {
        map[k] = obj[k] as Object?;
      }
    } else {
      throw ('fromJson decoded String is NOT a Map');
    }
    return map;
  }

  static Future<List<Map<String, Object?>>> select(DbTable table,
      {int limit = 50, int offset = 0, String search = ''}) async {
    return await DB.execute((Transaction txn) async {
      if (search.isEmpty) {
        return await txn.query(table.table,
            columns: table.columns, limit: limit, offset: offset);
      } else {
        var args = List.filled(table.columns.length, '%$search%');
        var where = <String>[];
        for (var col in table.columns) {
          where.add(' $col LIKE ? ');
        }

        return await txn.query(table.table,
            columns: table.columns,
            where: where.join(' OR '),
            whereArgs: args,
            limit: limit,
            offset: offset);
      }
    });
  }

  static Future<int> count(DbTable table, {String search = ''}) async {
    var col = 'ct';
    var rows = await DB.execute((Transaction txn) async {
      if (search.isEmpty) {
        return await txn.query(table.table,
            columns: ['count(*) AS $col'], limit: 1);
      } else {
        var args = List.filled(table.columns.length, '%$search%');
        var where = <String>[];
        for (var col in table.columns) {
          where.add(' $col LIKE ? ');
        }
        return await txn.query(table.table,
            columns: ['count(*) AS $col'],
            where: where.join(' OR '),
            whereArgs: args,
            limit: 1);
      }
    });
    if (rows.isNotEmpty) {
      return TypeAdapter.deserializeInt(rows.first[col]);
    }
    return 0;
  }
}
