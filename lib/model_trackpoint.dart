import 'dart:ffi';

import 'package:chaostours/model.dart';
import 'package:chaostours/model_task.dart';
import 'model_alias.dart';
import 'dart:io' as io;
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';

/*
example: 
await ModelTrackPoint.insert(ModelTrackPoint(
  lat: 1,
  lon: 2,
  trackPoints: [GPS(2, 3), GPS(4, 5)],
  timeStart: DateTime.now(),
  timeEnd: DateTime.now(),
  idAlias: [1, 5, 7],
  idTask: [3, 6, 5, 2],
  notes: 'this is a test'));

await ModelTrackPoint.update();

await ModelTrackPoint.write();

*/
class ModelTrackPoint {
  static final List<ModelTrackPoint> _table = [];
  int _id = 1;
  final int deleted; // 0 or 1
  final double lat;
  final double lon;
  final Set<GPS> trackPoints; // "lat,lon;lat,lon;..."
  final DateTime timeStart;
  final DateTime timeEnd;
  final Set<int> idAlias; // "id,id,..."
  final Set<int> idTask; // "id,id,..."
  final String notes;

  int get id => _id;
  static int get length => _table.length;

  ModelTrackPoint(
      {required this.lat,
      required this.lon,
      required this.timeStart,
      required this.timeEnd,
      this.deleted = 0,
      this.trackPoints = const {},
      this.idAlias = const {},
      this.idTask = const {},
      this.notes = ''});

  set notes(String n) {
    notes = n;
  }

  void addAlias(ModelAlias m) => idAlias.add(m.id);
  void removeAlias(ModelAlias m) => idAlias.remove(m.id);

  void addTask(ModelTask m) => idTask.add(m.id);
  void emoveTask(ModelTask m) => idTask.remove(m.id);

  void addTrackPoint(GPS gps) => trackPoints.add(gps);
  void removeTrackPoint(GPS gps) => trackPoints.remove(gps);

  List<ModelAlias> getAlias() {
    List<ModelAlias> list = [];
    for (int id in idAlias) {
      list.add(ModelAlias.getAlias(id));
    }
    return list;
  }

  static List<ModelTrackPoint> recentTrackPoints({int max = 30}) {
    List<ModelTrackPoint> list = [];
    int m = (max > _table.length ? _table.length : max) - 1;
    for (var i = _table.length - m; i < _table.length; i++) {
      list.add(_table[i]);
    }
    return list;
  }

  Set<ModelTask> getTask() {
    Set<ModelTask> list = {};
    idAlias.forEach((int id) {
      list.add(ModelTask.getTask(id));
    });
    return list;
  }

  static Future<int> insert(ModelTrackPoint m) async {
    _table.add(m);
    m._id = _table.length;
    await Model.insertRow(
        handle: await FileHandler.station, line: m.toString());
    return m._id;
  }

  static Future<int> open() async {
    List<String> lines = await FileHandler.readLines(DatabaseFile.station);
    _table.clear();
    Model.walkLines(lines, (String line) => _table.add(toModel(line)));
    logInfo('Trackpoints loaded ${_table.length} rows');
    return _table.length;
  }

  static Future<bool> update() => write();

  static Future<bool> write() async {
    await Model.writeTable(handle: await FileHandler.station, table: _table);
    return true;
  }

  static ModelTrackPoint toModel(String row) {
    List<String> p = row.split('\t');

    ModelTrackPoint tp = ModelTrackPoint(
        deleted: int.parse(p[1]),
        lat: double.parse(p[2]),
        lon: double.parse(p[3]),
        trackPoints: Model.parseTrackPointList(p[4]),
        timeStart: DateTime.parse(p[5]),
        timeEnd: DateTime.parse(p[6]),
        idAlias: Model.parseIdList(p[7]),
        idTask: Model.parseIdList(p[8]),
        notes: decode(p[9]));
    tp._id = int.parse(p[0]);
    return tp;
  }

  @override
  String toString() {
    List<String> parts = [
      _id.toString(),
      deleted.toString(),
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
