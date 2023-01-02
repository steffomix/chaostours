import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:chaostours/enum.dart';
import 'package:chaostours/model.dart';
import 'package:chaostours/file_handler.dart';

class ModelAlias {
  static final List<ModelAlias> _table = [];
  int _id = 0;
  int deleted;
  final double lat;
  final double lon;
  final int radius;
  final String alias;
  final String notes;
  final AliasStatus status;
  final DateTime lastVisited;
  final int timesVisited;

  int get id => _id;
  static int get length => _table.length;

  // temporary set during search for neares Alias
  int sortDistance = 0;

  ModelAlias(
      {required this.lat,
      required this.lon,
      required this.alias,
      required this.lastVisited,
      this.deleted = 0,
      this.radius = 100,
      this.notes = '',
      this.status = AliasStatus.public,
      this.timesVisited = 0});

  static ModelAlias toModel(String row) {
    List<String> p = row.trim().split('\t');
    int id = int.parse(p[0]);
    ModelAlias a = ModelAlias(
        deleted: int.parse(p[1]),
        lat: double.parse(p[2]),
        lon: double.parse(p[3]),
        radius: int.parse(p[4]),
        alias: decode(p[5]),
        notes: decode(p[6]),
        status: AliasStatus.byValue(int.parse(p[7])),
        lastVisited: DateTime.parse(p[8]),
        timesVisited: int.parse(p[9]));
    a._id = id;
    return a;
  }

  @override
  String toString() {
    List<String> l = [
      id.toString(),
      deleted.toString(),
      lat.toString(),
      lon.toString(),
      radius.toString(),
      encode(alias),
      encode(notes),
      status.value.toString(),
      lastVisited.toIso8601String(),
      timesVisited.toString()
    ];
    return l.join('\t');
  }

  static Future<int> insert(ModelAlias m) async {
    _table.add(m);
    m._id = _table.length;
    await write();
    return Future<int>.value(m._id);
  }

  static Future<bool> update() async {
    await write();
    return Future<bool>.value(true);
  }

  static Future<bool> delete(ModelAlias m) async {
    m.deleted = 1;
    await write();
    return Future<bool>.value(true);
  }

  // opens, read and parse database
  static Future<int> open() async {
    List<String> lines = await Model.readTable(DatabaseFile.alias);
    for (var row in lines) {
      _table.add(toModel(row));
    }
    logInfo('alias loaded ${_table.length} rows');
    return Future<int>.value(_table.length);
  }

  // writes the entire table back to disc
  static Future<bool> write() async {
    await Model.writeTable(handle: await FileHandler.alias, table: _table);
    return Future<bool>.value(true);
  }

  static ModelAlias get random {
    return _table[Random().nextInt(_table.length - 1)];
  }

  static ModelAlias getAlias(int id) {
    return _table[id - 1];
  }

  /// if all == false
  ///   returns only alias within their radius range distance from given gps
  /// else
  ///   returns all alias sorted by distance from gps
  ///
  /// The member sortDistance in meter can be used for user information
  static List<ModelAlias> nextAlias(GPS gps, [bool all = false]) {
    ModelAlias m;
    List<ModelAlias> list = [];
    for (var i = 0; i < _table.length - 1; i++) {
      m = _table[i];
      m.sortDistance =
          Geolocator.distanceBetween(m.lat, m.lon, gps.lat, gps.lon).round();
      if (all) {
        list.add(m);
      } else {
        if (m.sortDistance < m.radius) list.add(m);
      }
    }
    list.sort((a, b) => a.sortDistance.compareTo(b.sortDistance));
    return list;
  }

  static Future<int> openFromAsset() async {
    String string = await rootBundle.loadString('assets/alias.tsv');
    List<String> lines = string.trim().split(Model.lineSep);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    return _table.length;
  }
}
