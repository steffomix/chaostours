import 'package:chaostours/model.dart';
import 'package:chaostours/model_task.dart';
import 'dart:io' as io;
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';

class ModelTrackPoint {
  static List<ModelTrackPoint> _table = [];
  static int _nextId = 1;
  int _id = 1;
  final double lat;
  final double lon;
  final List<GPS> trackPoints;
  final DateTime timeStart;
  final DateTime timeEnd;
  final List<int> idAlias;
  final List<int> idTask;
  final String notes;

  int get id => _id;

  ModelTrackPoint(
      {required this.lat,
      required this.lon,
      required this.trackPoints,
      required this.timeStart,
      required this.timeEnd,
      this.idAlias = const [],
      this.idTask = const [],
      this.notes = ''});

  set notes(String n) {
    notes = n;
  }

  static Future<int> insert(ModelTrackPoint m) async {
    _table.add(m);
    m._id = _table.length;
    await Model.writeLine(
        handle: await FileHandler.station, line: m.toString());
    return m._id;
  }

  static Future<int> open() async {
    List<String> lines = await FileHandler.readLines(FileHandle.station);
    _table.clear();
    Model.walkLines(lines, (String line) => _table.add(toModel(line)));
    logInfo('Trackpoints loaded ${_table.length} rows');
    return _table.length;
  }

  static Future<bool> update() => write();

  static Future<bool> write() async {
    Model.writeTable(handle: await FileHandler.station, table: _table);
    return true;
  }

  static ModelTrackPoint toModel(String row) {
    List<String> p = row.split('\t');
    ModelTrackPoint tp = ModelTrackPoint(
        lat: double.parse(p[1]),
        lon: double.parse(p[2]),
        trackPoints: Model.parseTrackPointList(p[3]),
        timeStart: DateTime.parse(p[4]),
        timeEnd: DateTime.parse(p[5]),
        idAlias: Model.parseIdList(p[6]),
        idTask: Model.parseIdList(p[7]),
        notes: decode(p[8]));
    tp._id = int.parse(p[0]);
    return tp;
  }

  @override
  String toString() {
    List<String> parts = [
      _id.toString(),
      lat.toString(),
      lon.toString(),
      Model.trackPointsToString(trackPoints),
      timeStart.toIso8601String(),
      timeEnd.toIso8601String(),
      idAlias.join(','),
      idTask.join(','),
      encode(notes)
    ];
    return parts.join('\t');
  }
}
