import 'package:chaostours/model.dart';
import 'package:chaostours/model_task.dart';
import 'model_alias.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/events.dart';

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
  int _id = -1;
  final int deleted; // 0 or 1
  final double lat;
  final double lon;
  final Set<GPS> trackPoints; // "lat,lon;lat,lon;..."
  final DateTime timeStart;
  DateTime timeEnd;
  final Set<int> idAlias; // "id,id,..."
  final Set<int> idTask; // "id,id,..."
  String notes;

  int get id => _id;
  static int get length => _table.length;

  ModelTrackPoint(
      {this.deleted = 0,
      required this.lat,
      required this.lon,
      required this.timeStart,
      required this.timeEnd,
      required this.trackPoints,
      required this.idAlias,
      required this.idTask,
      this.notes = ''});

  static Future<int> insert(ModelTrackPoint m) async {
    _table.add(m);
    m._id = _table.length;
    await write();
    return Future<int>.value(m._id);
  }

  static Future<bool> update(TrackPointEvent model) async {
    if (model.model == null) return false; // not inserted yet
    model._id = model.model!.id;
    _table[model._id - 1] = model;
    return await write();
  }

  static Future<bool> write() async {
    await Model.writeTable(handle: await FileHandler.station, table: _table);
    return Future<bool>.value(true);
  }

  static Future<int> open() async {
    List<String> lines = await Model.readTable(DatabaseFile.station);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    logInfo('Trackpoints loaded ${_table.length} rows');
    return Future<int>.value(_table.length);
  }

  void addAlias(ModelAlias m) => idAlias.add(m.id);
  void removeAlias(ModelAlias m) => idAlias.remove(m.id);

  void addTask(ModelTask m) => idTask.add(m.id);
  void removeTask(ModelTask m) => idTask.remove(m.id);

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
    int i = _table.length;
    while (--max >= 0 && --i >= 0) {
      list.add(_table[i]);
    }
    return list.reversed.toList();
  }

  Set<ModelTask> getTask() {
    Set<ModelTask> list = {};
    for (int id in idAlias) {
      list.add(ModelTask.getTask(id));
    }
    return list;
  }

  static ModelTrackPoint toModel(String row) {
    List<String> p = row.split('\t');

    ModelTrackPoint tp = ModelTrackPoint(
        deleted: int.parse(p[1]),
        lat: double.parse(p[2]),
        lon: double.parse(p[3]),
        trackPoints: parseTrackPointList(p[4]),
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
    List<String> list = [];
    for (var gps in trackPoints) {
      list.add('${gps.lat},${gps.lon}');
    }
    List<String> parts = [
      _id.toString(),
      deleted.toString(),
      lat.toString(),
      lon.toString(),
      list.join(','),
      timeStart.toIso8601String(),
      timeEnd.toIso8601String(),
      idAlias.join(','),
      idTask.join(','),
      encode(notes)
    ];
    return parts.join('\t');
  }

  //
  static Set<GPS> parseTrackPointList(String string) {
    Set<GPS> tps = {};
    List<String> list = string.split(';').where((e) => e.isNotEmpty).toList();
    for (var item in list) {
      List<String> coords = item.split(',');
      tps.add(GPS(double.parse(coords[0]), double.parse(coords[1])));
    }
    return tps;
  }
}
