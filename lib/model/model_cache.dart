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
import 'package:chaostours/cache.dart';
import 'package:sqflite/sqlite_api.dart';

class DbCache {
  static const _table = CacheData.table;
  static final _id = CacheData.id.column;
  static final _key = CacheData.key.column;
  static final _data = CacheData.data.column;

  static DbCache? _instance;
  DbCache._();
  factory DbCache() => _instance ??= DbCache._();

  String id(Cache key) => key.name;

  Future<int> _count(Transaction txn, Cache key) async {
    var col = 'ct';
    var rows = await txn.rawQuery('SELECT count(*) FROM $_table AS $col');
    return DB.parseInt(rows.firstOrNull?[col]);
  }

  Future<int> count(Cache key) async {
    return DB.execute<int>((Transaction txn) async {
      return _count(txn, key);
    });
  }

  Future<void> remove(Cache key) async {
    await DB.execute((Transaction txn) async {
      await _delete(txn, key);
    });
  }

  Future<int> _delete(Transaction txn, Cache key) async {
    return await txn.delete(_table, where: '$_key = ?', whereArgs: [id(key)]);
  }

  Future<int> _set(Cache key, Object? value) async {
    return DB.execute<int>((Transaction txn) async {
      await _delete(txn, key);
      return await txn.insert(_table, {_id: 1, _key: id(key), _data: value});
    });
  }

  Future<void> _setList(Cache key, List<Object?> values) async {
    return DB.execute((Transaction txn) async {
      await _delete(txn, key);
      if (values.isEmpty) {
        return;
      }
      final batch = txn.batch();
      batch.delete(_table, where: '$_key = ?', whereArgs: [id(key)]);
      int i = 1;
      for (var value in values) {
        batch.insert(_table, {_id: i++, _key: id(key), _data: value});
      }
      batch.commit();
    });
  }

  Future<String?> _get(Cache key) async {
    final rows = await DB.execute(
      (Transaction txn) async {
        return await txn.query(_table,
            columns: [_data],
            where: '$_key = ?',
            whereArgs: [id(key)],
            limit: 1);
      },
    );
    return rows.firstOrNull?[_data].toString();
  }

  Future<List<String>> _getList(Cache key) async {
    final rows = await DB.execute(
      (Transaction txn) async {
        return await txn.query(_table,
            columns: [_data],
            where: '$_key = ?',
            whereArgs: [id(key)],
            orderBy: _id,
            limit: 1);
      },
    );
    final data = <String>[];
    String d;
    for (var row in rows) {
      d = row[_data].toString();
      if (d.isNotEmpty) {
        data.add(d);
      }
    }
    return data;
  }

  /// String
  Future<void> setString(Cache key, Object? value) async =>
      await _set(key, value);
  Future<String?> getString(Cache key) async => await _get(key);

  /// StringList
  Future<void> setStringList(Cache key, List<Object?> values) async =>
      await _setList(key, values);
  Future<List<String>?> getStringList(Cache key) async {
    final list = await _getList(key);
    return list.isEmpty ? null : list;
  }

  /// int
  Future<void> setInt(Cache key, int value) async =>
      await _set(key, value.toString());
  Future<int?> getInt(Cache key) async {
    final value = await _get(key);
    return value == null ? null : DB.parseInt(value);
  }

  /// double
  Future<void> setDouble(Cache key, double value) async =>
      await _set(key, value.toString());
  Future<double?> getDouble(Cache key) async {
    final value = await _get(key);
    return value == null ? null : DB.parseDouble(value);
  }

  /// bool
  Future<void> setBool(Cache key, bool value) async =>
      await _set(key, DB.boolToInt(value).toString());
  Future<bool> getBool(Cache key) async => DB.parseBool(await _get(key));
}
