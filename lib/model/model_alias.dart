import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:flutter/services.dart';
import 'dart:math';
//
import 'package:chaostours/enum.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';

enum AliasStatus {
  disabled(0),
  public(1),
  privat(2);

  final int value;
  const AliasStatus(this.value);

  static AliasStatus byValue(int id) {
    AliasStatus status =
        AliasStatus.values.firstWhere((status) => status.value == id);
    return status;
  }
}

class ModelAlias {
  static Logger logger = Logger.logger<ModelAlias>();
  static final List<ModelAlias> _table = [];
  int deleted;
  final double lat;
  final double lon;
  final int radius;
  final String alias;
  final String notes;
  final AliasStatus status;
  final DateTime lastVisited;
  final int timesVisited;
  static int _unsavedId = 0;

  /// autoincrement unsaved models into negative ids
  static get _nextUnsavedId => --_unsavedId;
  int _id = 0;

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
      required this.alias,
      required this.lastVisited,
      this.deleted = 0,
      this.radius = 100,
      this.notes = '',
      this.status = AliasStatus.public,
      this.timesVisited = 0}) {
    _id = _nextUnsavedId;
  }

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
      timesVisited.toString(),
      '|'
    ];
    return l.join('\t');
  }

  static Future<int> insert(ModelAlias m) async {
    _table.add(m);
    m._id = _table.length;
    logger.log('Insert Alias ${m.alias}\nwith ID #${m._id}');
    await write();
    return m._id;
  }

  static Future<void> update() async {
    logger.verbose('Update');
    await write();
  }

  static Future<void> delete(ModelAlias m) async {
    logger.log('Delete ${m.alias} with ID ${m.id}');
    m.deleted = 1;
    await write();
  }

  // opens, read and parse database
  static Future<int> open() async {
    List<String> lines = await Model.readTable<ModelAlias>();
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    logger.log('Table Alias loaded with ${_table.length} rows');
    return _table.length;
  }

  // writes the entire table back to disc
  static Future<bool> write() async {
    logger.verbose('Write Table');
    await Model.writeTable<ModelAlias>(
        _table.map((e) => e.toString()).toList());
    return true;
  }

  static String dump() {
    List<String> dump = [];
    for (var i in _table) {
      dump.add(i.toString());
    }
    return dump.join(Model.lineSep);
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
  /// The property sortDistance in meter can be used for user information
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
    logger.verbose('Found ${list.length} nearest Alias');
    return list;
  }

  static Future<int> openFromAsset() async {
    logger.warn('Loading built-in alias List from assets');
    String string = await rootBundle.loadString('assets/alias.tsv');
    List<String> lines = string.trim().split(Model.lineSep);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    return _table.length;
  }
}
