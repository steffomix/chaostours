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
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqlite_api.dart';

class SharedCache implements CacheModul {
  static SharedCache? _instance;
  SharedCache._();
  factory SharedCache() => _instance ??= SharedCache._();
  SharedPreferences? _sharedPreferencesInstance;

  @override
  Future<void> reload() async {
    (_sharedPreferencesInstance ??= await SharedPreferences.getInstance())
        .reload();
  }

  String _key(Cache key) {
    return 'com.stefanbrinkmann.chaostours.${key.name}';
  }

  @override
  Future<bool?> getBool(Cache key) async {
    return (_sharedPreferencesInstance ??=
            await SharedPreferences.getInstance())
        .getBool(_key(key));
  }

  @override
  Future<double?> getDouble(Cache key) async {
    return (_sharedPreferencesInstance ??=
            await SharedPreferences.getInstance())
        .getDouble(_key(key));
  }

  @override
  Future<int?> getInt(Cache key) async {
    return (_sharedPreferencesInstance ??=
            await SharedPreferences.getInstance())
        .getInt(_key(key));
  }

  @override
  Future<String?> getString(Cache key) async {
    return (_sharedPreferencesInstance ??=
            await SharedPreferences.getInstance())
        .getString(_key(key));
  }

  @override
  Future<List<String>?> getStringList(Cache key) async {
    return (_sharedPreferencesInstance ??=
            await SharedPreferences.getInstance())
        .getStringList(_key(key));
  }

  @override
  Future<void> setBool(Cache key, bool value) async {
    (_sharedPreferencesInstance ??= await SharedPreferences.getInstance())
        .setBool(_key(key), value);
  }

  @override
  Future<void> setDouble(Cache key, double value) async {
    (_sharedPreferencesInstance ??= await SharedPreferences.getInstance())
        .setDouble(_key(key), value);
  }

  @override
  Future<void> setInt(Cache key, int value) async {
    (_sharedPreferencesInstance ??= await SharedPreferences.getInstance())
        .setInt(_key(key), value);
  }

  @override
  Future<void> setString(Cache key, String value) async {
    (_sharedPreferencesInstance ??= await SharedPreferences.getInstance())
        .setString(_key(key), value);
  }

  @override
  Future<void> setStringList(Cache key, List<String> value) async {
    (_sharedPreferencesInstance ??= await SharedPreferences.getInstance())
        .setStringList(_key(key), value);
  }

  @override
  Future<void> remove(Cache key) async {
    (_sharedPreferencesInstance ??= await SharedPreferences.getInstance())
        .remove(_key(key));
  }
}

class DbCache implements CacheModul {
  static DbCache? _instance;
  DbCache._();
  factory DbCache() => _instance ??= DbCache._();

  final _table = CacheData.table;
  final _id = CacheData.id.column;
  final _key = CacheData.key.column;
  final _data = CacheData.data.column;

  String id(Cache key) => key.name;

  Future<int> _count(Transaction txn, Cache key) async {
    var col = 'ct';
    var rows = await txn.rawQuery('SELECT count(*) FROM $_table AS $col');
    return TypeAdapter.deserializeInt(rows.firstOrNull?[col]);
  }

  Future<int> count(Cache key) async {
    return DB.execute<int>((Transaction txn) async {
      return _count(txn, key);
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
      int i = 1;
      for (var value in values) {
        await txn.insert(_table, {_id: i++, _key: id(key), _data: value});
      }
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
            orderBy: _id);
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
  @override
  Future<void> setString(Cache key, Object? value) async =>
      await _set(key, value);
  @override
  Future<String?> getString(Cache key) async => await _get(key);

  /// StringList
  @override
  Future<void> setStringList(Cache key, List<Object?> values) async =>
      await _setList(key, values);
  @override
  Future<List<String>?> getStringList(Cache key) async {
    final list = await _getList(key);
    return list.isEmpty ? null : list;
  }

  /// int
  @override
  Future<void> setInt(Cache key, int value) async =>
      await _set(key, value.toString());
  @override
  Future<int?> getInt(Cache key) async {
    final value = await _get(key);
    return value == null ? null : TypeAdapter.deserializeInt(value);
  }

  /// double
  @override
  Future<void> setDouble(Cache key, double value) async =>
      await _set(key, value.toString());
  @override
  Future<double?> getDouble(Cache key) async {
    final value = await _get(key);
    return value == null ? null : TypeAdapter.deserializeDouble(value);
  }

  /// bool
  @override
  Future<void> setBool(Cache key, bool value) async =>
      await _set(key, TypeAdapter.serializeBool(value).toString());
  @override
  Future<bool> getBool(Cache key) async =>
      TypeAdapter.deserializeBool(await _get(key));

  @override
  Future<void> remove(Cache key) async {
    await DB.execute((Transaction txn) async {
      await _delete(txn, key);
    });
  }

  @override
  Future<void> reload() async {
    // do nothing
  }
}
