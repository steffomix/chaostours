import 'package:geolocator/geolocator.dart' show Geolocator;
import 'dart:io' as io;
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:chaostours/enum.dart';

var decode = util.base64Codec().decode;
var encode = util.base64Codec().encode;

class ModelHandle {
  static Map<FileHandle, io.File?> handles = {
    FileHandle.alias: null,
    FileHandle.task: null,
    FileHandle.station: null
  };
  static Future<io.File> get alias => _handle(FileHandle.alias);
  static Future<io.File> get task => _handle(FileHandle.task);
  static Future<io.File> get station => _handle(FileHandle.station);

  static Future<io.File> _handle(FileHandle filename) async {
    if (handles[filename] != null) {
      return Future<io.File>.value(handles[filename]);
    }
    handles[filename] = await RecourceLoader.fileHandle('${filename.name}.tsv');
    return Future<io.File>.value(handles[filename]);
  }
}

class ModelTrackPoint {
  static final List<ModelTask> _table = [];

  static Future<bool> open() async {
    io.File handle = await ModelHandle.alias;
    String string = await handle.readAsString();
    List<String> lines = string.split('\n');
    String l;
    String p;
    for (var i = 0; i < lines.length - 1; i++) {}

    return true;
  }
}

class ModelTask {
  final int id;
  final String task;
  ModelTask(this.id, this.task);
}

class ModelAlias {
  static final List<ModelAlias> _table = [];
  static int _nextId = 0;
  int _id = 0; // for delete search only, will not be saved to disc
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

  static void insert(ModelAlias m) {
    _nextId++;
    _table.add(m);
    write();
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
  static Future<bool> open() async {
    io.File handle = await ModelHandle.alias;
    String string = await handle.readAsString();
    List<String> lines = string.split('\n');
    try {
      _nextId = int.parse(lines.first.trim());
    } catch (e) {
      _nextId = 0;
    }
    String l;
    List<String> p;
    _table.clear();
    int id;
    int i = 0;
    while (true) {
      try {
        l = lines[++i];
      } catch (e) {
        break;
      }

      try {
        p = l.trim().split('\t');
        id = int.parse(p[0]);
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
        _table.add(a);
      } catch (e) {
        logError('$e:\n$l');
      }
    }

    return true;
  }

  // writes the entire table back to disc
  static write() async {
    io.File handle = await ModelHandle.alias;
    List<String> lines = [_nextId.toString()];
    List<String> l;
    int i = -1;
    ModelAlias m;
    while (true) {
      try {
        m = _table[++i];
      } catch (e) {
        break;
      }

      l = [
        m.id.toString(),
        m.lat.toString(),
        m.lon.toString(),
        m.radius.toString(),
        encode(m.alias),
        encode(m.notes),
        m.status.value.toString(),
        m.lastVisited.toIso8601String(),
        m.timesVisited.toString()
      ];
      lines.add(l.join('\t'));
    }
    ;

    String out = lines.join('\n');
    await handle.writeAsString(out);
    return true;
  }

  static Future<bool> openFromAsset() async {
    String string = await rootBundle.loadString('assets/alias.tsv');
    List<String> lines = string.split('\n');
    try {
      _nextId = int.parse(lines.first.trim());
    } catch (e) {
      _nextId = 0;
    }
    String l;
    List<String> p;
    _table.clear();
    int id = 0;
    int i = 0;
    while (true) {
      try {
        l = lines[++i].trim();
      } catch (e) {
        break;
      }

      p = l.split('\t');
      try {
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
      } catch (e) {
        logError('$e:\n${lines[i]}');
      }
    }
    return true;
  }
}
