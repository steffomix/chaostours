import 'package:chaostours/model.dart';
import 'package:chaostours/model_task.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/track_point.dart';
import 'package:chaostours/util.dart' as util;

class ModelTrackPoint {
  static final List<ModelTrackPoint> _table = [];

  ///
  /// TrackPoint owners
  ///
  TrackingStatus status = TrackingStatus.none;
  static int _nextTrackingId = 0;
  int trackingId = 0; // needed for debug only

  ///
  /// Model owners
  ///
  int? _id;
  int deleted = 0; // 0 or 1
  GPS gps;
  List<ModelTrackPoint> trackPoints; // "lat,lon;lat,lon;..."
  DateTime timeStart;
  DateTime? _timeEnd;
  List<int> idAlias = []; // "id,id,..." needs to be sorted by distance
  List<int> idTask = []; // "id,id,..." needs to be ordered by user
  String notes = '';
  Address address;

  set timeEnd(DateTime t) => _timeEnd = t;

  /// throws if timeEnd is [t] not yert set
  DateTime get timeEnd {
    if (_timeEnd == null) throw 'ModelTrackPoint _timeEnd not yet set';
    return _timeEnd!;
  }

  int get id {
    if (_id == null) throw 'ModelTrackPoint _id not yet set';
    return _id!;
  }

  static int get length => _table.length;

  ModelTrackPoint(
      {required this.gps,
      required this.trackPoints,
      required this.idAlias,
      required this.timeStart,
      required this.address,
      this.deleted = 0,
      this.notes = ''}) {
    trackingId = ++_nextTrackingId;
  }

  static Future<int> insert(ModelTrackPoint m) async {
    _table.add(m);
    m._id = _table.length;
    await write();
    return Future<int>.value(m._id);
  }

  static Future<bool> update() async {
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
    GPS gps = GPS(double.parse(p[2]), double.parse(p[3]));
    ModelTrackPoint tp = ModelTrackPoint(
        deleted: int.parse(p[1]),
        gps: gps,
        address: Address(gps),
        timeStart: DateTime.parse(p[4]),
        trackPoints: parseTrackPointList(p[6]),
        idAlias: Model.parseIdList(p[7]),
        notes: decode(p[9]));

    tp._id = int.parse(p[0]);
    tp.timeEnd = DateTime.parse(p[5]);
    tp.idTask = Model.parseIdList(p[8]);
    return tp;
  }

  @override
  String toString() {
    /*
    List<String> list = [];
    for (var tp in trackPoints) {
      list.add('${tp.gps.lat},${tp.gps.lon}');
    }
    */
    List<String> parts = [
      _id.toString(), // 0
      deleted.toString(), // 1
      gps.lat.toString(), // 2
      gps.lon.toString(), // 3
      timeStart.toIso8601String(), // 4
      timeEnd.toIso8601String(), // 5
      trackPoints
          .map((tp) => '${(tp.gps.lat * 10000).round() / 10000},'
              '${(tp.gps.lon * 10000).round() / 10000}')
          .toList()
          .join(';'), //list.join(';'), // 6
      idAlias.join(','), // 7
      idTask.join(','), // 8
      encode(notes) // 9
    ];
    return parts.join('\t');
  }

  //
  static List<ModelTrackPoint> parseTrackPointList(String string) {
    //return tps;
    List<String> list = string.split(';').where((e) => e.isNotEmpty).toList();
    GPS gps;
    List<ModelTrackPoint> tps = [];
    for (var item in list) {
      List<String> coords = item.split(',');
      gps = GPS(double.parse(coords[0]), double.parse(coords[1]));
      ModelTrackPoint tp = ModelTrackPoint(
          gps: gps,
          address: Address(gps),
          trackPoints: <ModelTrackPoint>[],
          idAlias: ModelAlias.nextAlias(gps).map((m) => m.id).toList(),
          timeStart: DateTime.now());
      tps.add(tp);
    }
    return tps;
  }
}
