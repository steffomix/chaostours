import 'package:geolocator/geolocator.dart' show Geolocator;
import 'dart:io' as io;
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:chaostours/enum.dart';
import 'package:chaostours/model.dart';
import 'package:chaostours/file_handler.dart';

class ModelAlias {
  static List<ModelAlias> _table = [];
  int _id = 0;
  final double lat;
  final double lon;
  final int radius;
  final String alias;
  final String notes;
  final AliasStatus status;
  final DateTime lastVisited;
  final int timesVisited;

  int get id => _id;

  // temporary set during search for neares Alias
  int sortDistance = 0;

  ModelAlias(
      {required this.lat,
      required this.lon,
      required this.radius,
      required this.alias,
      required this.notes,
      required this.status,
      required this.lastVisited,
      required this.timesVisited});

  static ModelAlias get random {
    return _table[Random().nextInt(_table.length - 1)];
  }

  static Future<int> insert(ModelAlias m) async {
    _table.add(m);
    m._id = _table.length;
    await Model.writeLine(handle: await FileHandler.alias, line: m.toString());
    return m._id;
  }

  static void delete(ModelAlias m) {
    _table.removeWhere((e) => e.id == m.id);
    write();
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

  static void update() => write();

  // opens, read and parse database
  static Future<int> open() async {
    List<String> lines = await FileHandler.readLines(FileHandle.alias);
    Model.walkLines(lines, (row) => _table.add(toModel(row)));
    logInfo('alias loaded ${_table.length} rows');
    return _table.length;
  }

  // writes the entire table back to disc
  static Future<bool> write() async {
    Model.writeTable(handle: await FileHandler.alias, table: _table);
    return true;
  }

  static Future<int> openFromAsset() async {
    String string = await rootBundle.loadString('assets/alias.tsv');
    List<String> lines = string.split(FileHandler.lineSeperator);
    _table.clear();
    List<String> p;
    int id = 0;
    Model.walkLines(lines, (l) {
      p = l.split('\t');
      ModelAlias a = ModelAlias(
          lat: double.parse(p[0]),
          lon: double.parse(p[1]),
          radius: int.parse(p[2]),
          alias: p[3],
          notes: p[4],
          status: AliasStatus.byValue(int.parse(p[5])),
          lastVisited: DateTime.parse(p[6]),
          timesVisited: int.parse(p[7]));
      a._id = ++id;
      _table.add(a);
    });
    return id;
  }

  static ModelAlias toModel(String row) {
    List<String> p = row.trim().split('\t');
    int id = int.parse(p[0]);
    ModelAlias a = ModelAlias(
        lat: double.parse(p[1]),
        lon: double.parse(p[2]),
        radius: int.parse(p[3]),
        alias: decode(p[4]),
        notes: decode(p[5]),
        status: AliasStatus.byValue(int.parse(p[6])),
        lastVisited: DateTime.parse(p[7]),
        timesVisited: int.parse(p[8]));
    a._id = id;
    return a;
  }

  @override
  String toString() {
    List<String> l = [
      id.toString(),
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
}
