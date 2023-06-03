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

import 'package:flutter/services.dart';
//
import 'package:chaostours/model/model.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';

class ModelTask extends Model {
  static Logger logger = Logger.logger<ModelTask>();
  static final List<ModelTask> _table = [];
  int _id = 0;
  int sortOrder = 0;

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length
  int get id => _id;
  static int get length => _table.length;

  ModelTask({super.title, super.notes, super.deleted});

  static ModelTask getModel(int id) {
    return _table[id - 1];
  }

  static List<ModelTask> getAll() {
    var list = [..._table];
    list.sort((a, b) => a.sortOrder - b.sortOrder);
    return list;
  }

  @override
  String toString() {
    List<String> parts = [
      _id.toString(),
      sortOrder.toString(),
      deleted ? '1' : '0',
      encode(title),
      encode(notes),
      '|'
    ];
    return parts.join('\t');
  }

  static T _parse<T>(
      int field, String fieldName, String str, T Function(String s) fn) {
    try {
      return fn(str);
    } catch (e) {
      throw ('Parse error at column ${field + 1} ($fieldName): $e');
    }
  }

  static ModelTask toModel(String row) {
    List<String> p = row.split('\t');
    if (p.length < 5) {
      throw ('Table Task must have at least 4 columns: 1:ID, 2:deleted, 3:task name, 4:notes');
    }
    int id = _parse<int>(0, 'ID', p[0], int.parse); // int.parse(parts[0]);
    int sortOrder = _parse<int>(1, 'ID', p[1], int.parse);
    ModelTask model = ModelTask(
        deleted: _parse<int>(1, 'Deleted', p[2], int.parse) == 1
            ? true
            : false, //p[1] == '1' ? true : false,
        title: _parse<String>(2, 'Task name', p[3], decode), //decode(p[2]),
        notes: _parse<String>(3, 'Notes', p[4], decode)); // decode(p[3]));
    model._id = id;
    model.sortOrder = sortOrder;
    return model;
  }

  static Future<int> open() async {
    await Cache.reload();
    _table.clear();
    _table.addAll(
        await Cache.getValue<List<ModelTask>>(CacheKeys.tableModelTask, []));
    return _table.length;
  }

  /// returns task id
  static Future<int> insert(ModelTask m) async {
    _table.add(m);
    m._id = _table.length;
    logger.log('Insert Task ${m.title} \n    which now has ID $m._id');
    await write();
    return m._id;
  }

  static Future<void> update([ModelTask? m]) async {
    if (m != null && _table.indexWhere((e) => e.id == m.id) >= 0) {
      _table[m.id - 1] = m;
    }
    await write();
  }

  ModelTask clone() {
    return toModel(toString());
  }

  static Future<void> delete(ModelTask m) async {
    m.deleted = true;
    logger.log('Delete Task ${m.title} with ID ${m.id}');
    await write();
  }

  // writes the entire table back to disc
  static Future<void> write() async {
    await Cache.setValue<List<ModelTask>>(CacheKeys.tableModelTask, _table);
  }

  static String dump() {
    List<String> dump = [];
    for (var i in _table) {
      dump.add(i.toString());
    }
    return dump.join(Model.lineSep);
  }
}
