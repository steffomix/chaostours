import 'package:chaostours/model.dart';
import 'package:chaostours/model_task.dart';
import 'package:chaostours/model_alias.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/file_handler.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';

class ModelTrackPoint {
  static Logger logger = Logger.logger<ModelTrackPoint>();
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
  DateTime timeEnd = DateTime.now();
  List<int> idAlias = []; // "id,id,..." needs to be sorted by distance
  List<int> idTask = []; // "id,id,..." needs to be ordered by user
  String notes = '';
  Address address;
/*
  set timeEnd(DateTime t) => _timeEnd = t;

  /// throws if timeEnd is [t] not yert set
  DateTime get timeEnd {
    if (_timeEnd == null) throw 'ModelTrackPoint _timeEnd not yet set';
    return _timeEnd!;
  }
*/
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

  String timeElapsed() {
    return util.timeElapsed(timeStart, timeEnd);
  }

  static String dumpTable() {
    List<String> lines = [];
    for (var line in _table) {
      lines.add(line.toString());
    }
    String end = '${Model.rowEnd}${Model.lineSep}';
    String dump = lines.join(end);
    dump += end;
    return dump;
  }

  /// calculates route or distance, depending on TrackingStatus status
  /// route on moving and distance on standing
  double distance() {
    if (trackPoints.isEmpty) return 0.0;
    double dist;
    if (status == TrackingStatus.standing) {
      dist = GPS.distance(trackPoints.first.gps, trackPoints.last.gps);
    } else {
      dist = _distanceRoute();
    }
    return (dist).round() / 1000;
  }

  // calc distance over multiple trackpoints in meters
  double _distanceRoute() {
    if (trackPoints.length < 2) return 0;
    double dist = 0;
    GPS gps = trackPoints[0].gps;
    for (var i = 1; i < trackPoints.length; i++) {
      dist += GPS.distance(gps, trackPoints[i].gps);
      gps = trackPoints[i].gps;
    }
    return dist;
  }

  ///
  /// insert only if Model doesn't have a valid (not null) _id
  /// otherwise writes table to disk
  ///
  static Future<void> insert(ModelTrackPoint m) async {
    if (m._id == null) {
      _table.add(m);
      m._id = _table.length;
      logger.log('Insert TrackPoint ${m.gps}\n   which has now ID ${m._id}');
    } else {
      logger.warn(
          'Insert Trackpoint skipped. TrackPoint already inserted with ID ${m._id}');
    }
    await write();
  }

  ///
  /// Returns true if Model existed
  /// otherwise false and Model will be inserted.
  /// The Model will then have a valid id
  /// that reflects (is same as) Table length.
  ///
  static Future<void> update(ModelTrackPoint tp) async {
    if (tp._id == null) {
      logger.warn(
          'Update Trackpoint forwarded to insert due to TrackPoint has no ID');
      await insert(tp);
    } else {
      await write();
    }
  }

  static Future<void> write() async {
    logger.verbose('Write');
    await Model.writeTable(handle: await FileHandler.station, table: _table);
  }

  static Future<void> open() async {
    List<String> lines = await Model.readTable(DatabaseFile.station);
    _table.clear();
    for (var row in lines) {
      _table.add(toModel(row));
    }
    logger.log('Trackpoints loaded with ${_table.length} rows');
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
    logger.verbose('get ${list.length} alias from TrackPoint ID $id');
    return list;
  }

  static List<ModelTrackPoint> recentTrackPoints({int max = 30}) {
    List<ModelTrackPoint> list = [];
    int i = _table.length;
    while (--max >= 0 && --i >= 0) {
      list.add(_table[i]);
    }
    logger.verbose('${list.length} recentTrackPoints');
    return list.reversed.toList();
  }

  Set<ModelTask> getTask() {
    Set<ModelTask> list = {};
    for (int id in idAlias) {
      list.add(ModelTask.getTask(id));
    }
    logger.log('get Tasks: $list');
    return list;
  }

  static ModelTrackPoint toModel(String row) {
    List<String> p = row.split('\t');
    GPS gps = GPS(double.parse(p[3]), double.parse(p[4]));
    ModelTrackPoint tp = ModelTrackPoint(
        deleted: int.parse(p[1]),
        gps: gps,
        address: Address(gps),
        timeStart: DateTime.parse(p[5]),
        trackPoints: parseTrackPointList(p[7]),
        idAlias: Model.parseIdList(p[8]),
        notes: decode(p[10]));

    tp._id = int.parse(p[0]);
    tp.timeEnd = DateTime.parse(p[6]);
    tp.idTask = Model.parseIdList(p[9]);
    tp.status = TrackingStatus.byValue(int.parse(p[2]));
    return tp;
  }

  @override
  String toString() {
    List<String> cols = [
      _id.toString(), // 0
      deleted.toString(), // 1
      status.index.toString(), // 2
      gps.lat.toString(), // 3
      gps.lon.toString(), // 4
      timeStart.toIso8601String(), // 5
      timeEnd.toIso8601String(), // 6
      status == TrackingStatus.moving
          ? trackPoints
              .map((tp) => '${(tp.gps.lat * 10000).round() / 10000},'
                  '${(tp.gps.lon * 10000).round() / 10000}')
              .toList()
              .join(';')
          : '', //list.join(';'), // 7
      idAlias.join(','), // 8
      idTask.join(','), // 9
      encode(notes) // 10
    ];
    return cols.join('\t');
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
