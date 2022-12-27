import 'package:geolocator/geolocator.dart' show Geolocator;
import 'dart:io' as io;
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/gps.dart';

class ModelAlias {
  static final List<ModelAlias> _table = [];
  final int id; // for delete search only, will not be saved to disc
  final double lat;
  final double lon;
  final int radius;
  final String alias;
  final String notes;
  final AliasStatus status;
  final DateTime lastVisited;
  final int timesVisited;

  // temporary set during search for neares Alias
  int sortDistance = 0;

  ModelAlias(
      {required this.id,
      required this.lat,
      required this.lon,
      required this.radius,
      required this.alias,
      required this.notes,
      required this.status,
      required this.lastVisited,
      required this.timesVisited});

  static io.File? _handle;
  static Future<io.File> fileHandle() async {
    if (_handle != null) return Future<io.File>.value(_handle);
    _handle = await RecourceLoader.modelAliasHandle();
    return Future<io.File>.value(_handle);
  }

  // opens, read and parse database
  static open() async {
    io.File handle = await fileHandle();
    String string = await handle.readAsString();
    List<String> lines = string.split('\n');
    String l;
    List<String> p;
    _table.clear();
    int id = 0;
    for (var i = 0; i < lines.length - 1; i++) {
      l = util.base64Codec().decode(lines[i]);
      p = l.trim().split('\t');
      try {
        _table.add(ModelAlias(
            id: ++id,
            lat: double.parse(p[0]),
            lon: double.parse(p[1]),
            radius: int.parse(p[2]),
            alias: util.base64Codec().decode(p[3]),
            notes: util.base64Codec().decode(p[4]),
            status: AliasStatus.byValue(int.parse(p[5])),
            lastVisited: DateTime.parse(p[6]),
            timesVisited: int.parse(p[7])));
      } catch (e) {
        logError('$e:\n${lines[i]}');
      }
    }
  }

  static void insert(ModelAlias m) {
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

  // writes the entire table back to disc
  static write() async {
    io.File handle = await fileHandle();
    List<String> lines = [];
    List<String> l;
    for (var i = 0; i < _table.length - 1; i++) {
      ModelAlias m = _table[i];
      l = [
        m.lat.toString(),
        m.lon.toString(),
        m.radius.toString(),
        util.base64Codec().encode(m.alias),
        util.base64Codec().encode(m.notes),
        m.status.value.toString(),
        m.lastVisited.toIso8601String(),
        m.timesVisited.toString()
      ];
      lines.add(util.base64Codec().encode(l.join('\t')));
    }
    String out = lines.join('\n');
    handle.writeAsString(out, mode: io.FileMode.write);
  }
}
