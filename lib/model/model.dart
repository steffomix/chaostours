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

import 'package:chaostours/logger.dart';
import 'package:chaostours/database.dart';
import 'package:sqflite/sqflite.dart';

var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull;

class Model {
  static final Logger logger = Logger.logger<Model>();
  static const String lineSep = '\n';

  static final List<TableFields> tables = List.unmodifiable([
    TableFields(TableTrackPoint.table, TableTrackPoint.columns),
    TableFields(TableTrackPointAlias.table, TableTrackPoint.columns),
    TableFields(TableTrackPointTask.table, TableTrackPointTask.columns),
    TableFields(TableTrackPointUser.table, TableTrackPointUser.columns),
    TableFields(TableTask.table, TableTask.columns),
    TableFields(TableAlias.table, TableAlias.columns),
    TableFields(TableUser.table, TableUser.columns),
    TableFields(TableTaskGroup.table, TableTaskGroup.columns),
    TableFields(TableAliasGroup.table, TableAliasGroup.columns),
    TableFields(TableUserGroup.table, TableUserGroup.columns),
    TableFields(TableTopic.table, TableTopic.columns),
    TableFields(TableAliasTopic.table, TableAliasTopic.columns)
  ]);

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

  static Future<List<Map<String, Object?>>> select(TableFields table,
      {int limit = 50, int offset = 0}) async {
    return await DB.execute((Transaction txn) async {
      return await txn.query(table.table,
          columns: table.columns, limit: limit, offset: offset);
    });
  }
}
