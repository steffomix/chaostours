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

import 'dart:math';
import 'package:flutter/services.dart';

///
import 'package:chaostours/model/model.dart';
import 'package:chaostours/database.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:sqflite/sqflite.dart';

enum AliasStatus {
  public(1),
  privat(2),
  restricted(3);

  final int value;
  const AliasStatus(this.value);

  static AliasStatus byValue(int id) {
    AliasStatus status =
        AliasStatus.values.firstWhere((status) => status.value == id);
    return status;
  }
}

class ModelAlias extends Model {
  static Logger logger = Logger.logger<ModelAlias>();
  static final List<ModelAlias> _table = [];
  double lat;
  double lon;
  int radius;
  AliasStatus status;
  final List<int> idTrackPoint = [];
  DateTime lastVisited;

  int timesVisited;
  int _id = 0;

  String calendarId = '';

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length
  int get id => _id;
  static int get length => _table.length;

  /// temporary set during search for nearest Alias
  int sortDistance = 0;

  ModelAlias(
      {required this.lat,
      required this.lon,
      required this.lastVisited,
      this.radius = 50,
      this.status = AliasStatus.public,
      this.timesVisited = 0,
      super.title,
      super.deleted,
      super.notes});

  static Future<ModelAlias> byId(int id) async {}

  static Future<List<ModelAlias>> byIdList(List<int> ids) async {}

  /// transforms text into %text%
  static Future<List<ModelAlias>> search(String text) async {
    text = '%$text%';
    var rows = await DB.query<List<Map<String, Object?>>>(
      (txn) async {
        return await txn.query(TableAlias.table,
            where:
                '${TableAlias.title} like ? OR ${TableAlias.description} like ?',
            whereArgs: [text, text]);
      },
    );
    var models = <ModelAlias>[];
    for (var row in rows) {
      try {
        models.add(_fromMap(row));
      } catch (e, stk) {
        logger.error('search: $e', stk);
      }
    }
    return models;
  }

  static Future<List<ModelTrackPoint>> lastVisited(GPS gps) async {
    var radius = AppSettings.distanceTreshold;
    var rows = ModelAlias.byRadius(gps, radius);
  }

  ///
  static Future<List<ModelAlias>> byRadius(
      {required GPS gps, required int radius}) async {
    var area = GpsArea.calculateArea(
        latitude: gps.lat, longitude: gps.lon, distance: radius);
    var table = TableAlias.table;
    var latCol = TableAlias.latitude.column;
    var lonCol = TableAlias.longitude.column;
    var rows = await DB.query(
      (Transaction txn) async {
        return await txn.query(table,
            where:
                '$latCol > ? AND $latCol < ? AND $lonCol > ? AND $lonCol < ?',
            whereArgs: [area.latMin, area.latMax, area.lonMin, area.lonMax]);
      },
    );
    var rawModels = <ModelAlias>[];
    for (var row in rows) {
      rawModels.add(_fromMap(row));
    }
    var models = <ModelAlias>[];
    for (var model in rawModels) {
      if (GPS.distance(GPS(model.lat, model.lon), gps) <= radius) {
        models.add(model);
      }
    }
    return models;
  }

  static ModelAlias _fromMap(Map<String, Object?> map) {
    return ModelAlias();
  }

  static List<ModelAlias> getAll() => <ModelAlias>[..._table];

  static T _parse<T>(
      int field, String fieldName, String str, T Function(String s) fn) {
    try {
      return fn(str);
    } catch (e) {
      throw ('Parse error at column ${field + 1} ($fieldName): $e');
    }
  }

  static ModelAlias toModel(String row) {
    List<String> p = row.trim().split('\t');
    if (p.length < 10) {
      throw ('Table Alias must have at least 10 columns: 1:ID, 2: deleted, 3: latitude, 4: longitude, 5: radius, '
          '6: alias name, 7: notes, 8: alias type, 9: last visited, 10: count visted');
    }
    int id = _parse<int>(0, 'ID', p[0], int.parse); // int.parse(p[0]);
    var aliasType = _parse<int>(7, 'Alias Type', p[7], int.parse);
    if (!(aliasType >= 0 && aliasType <= 2)) {
      throw ('Alias Type must be 0: resticted, 1: private, or 2: public');
    }

    ModelAlias a = ModelAlias(
        deleted: _parse<int>(1, 'Deleted', p[1], int.parse) == 1
            ? true
            : false, // p[1] == '1' ? true : false,
        lat: _parse<double>(
            2, 'Latitude', p[2], double.parse), //double.parse(p[2]),
        lon: _parse<double>(
            3, 'Longitude', p[3], double.parse), // double.parse(p[3]),
        radius: _parse<int>(4, 'Radius', p[4], int.parse), // int.parse(p[4]),
        title: _parse<String>(5, 'Alias Name', p[5], decode), //decode(p[5]),
        notes: _parse<String>(6, 'Notes', p[6], decode), //decode(p[6]),
        status: AliasStatus.byValue(aliasType),
        lastVisited: _parse<DateTime>(
            8, 'Last visited', p[8], DateTime.parse), // DateTime.parse(p[8]),
        timesVisited: _parse<int>(
            9, 'Count visited', p[9], int.parse)); //int.parse(p[9]));
    a._id = id;
    return a;
  }

  @override
  String toString() {
    List<String> l = [
      id.toString(),
      deleted ? '1' : '0',
      lat.toString(),
      lon.toString(),
      radius.toString(),
      encode(title),
      encode(notes),
      status.value.toString(),
      lastVisited.toIso8601String(),
      timesVisited.toString(),
      '|'
    ];
    return l.join('\t');
  }

  /// returns alias id
  static Future<int> insert(ModelAlias m) async {
    _table.add(m);
    m._id = _table.length;
    logger.log('Insert Alias ${m.title}\nwith ID #${m._id}');
    await write();
    return m._id;
  }

  static Future<void> update([ModelAlias? m]) async {
    if (m != null && _table.indexWhere((e) => e.id == m.id) >= 0) {
      _table[m.id - 1] = m;
    }
    await write();
  }

  ModelAlias clone() {
    return toModel(toString());
  }

  static Future<void> delete(ModelAlias m) async {
    logger.log('Delete ${m.title} with ID ${m.id}');
    m.deleted = true;
    await write();
  }

  // opens, read and parse database
  static Future<int> open() async {
    Cache.reload();
    _table.clear();
    _table.addAll(
        await Cache.getValue<List<ModelAlias>>(CacheKeys.tableModelAlias, []));
    return _table.length;
  }

  // writes the entire table back to disc
  static Future<void> write() async {
    await Cache.setValue<List<ModelAlias>>(CacheKeys.tableModelAlias, _table);
  }

  static String dump() {
    List<String> dump = [];
    for (var i in _table) {
      dump.add(i.toString());
    }
    return dump.join(Model.lineSep);
  }

  static Future<ModelAlias> getModel(int id) async {
    return _table[id - 1];
  }

  /// if all == false
  ///   returns only alias within their radius range distance from given gps
  /// else
  ///   returns all alias sorted by distance from gps
  ///
  /// The property sortDistance in meter can be used for user information
  static List<ModelAlias> nextAlias(
      {required GPS gps, bool all = false, excludeDeleted = false}) {
    ModelAlias m;
    List<ModelAlias> list = [];
    for (var m in _table) {
      if (excludeDeleted && m.deleted) {
        continue;
      }
      m.sortDistance =
          GPS.distanceBetween(m.lat, m.lon, gps.lat, gps.lon).round();

      if (all) {
        list.add(m);
      } else {
        if (m.sortDistance < m.radius) {
          list.add(m);
        }
      }
    }
    list.sort((a, b) => a.sortDistance.compareTo(b.sortDistance));
    return list;
  }

  static List<ModelAlias> lastVisitedAlias([bool all = false]) {
    List<ModelAlias> list = [..._table];
    list.sort((a, b) => b.lastVisited.compareTo(a.lastVisited));
    return list;
  }
}
