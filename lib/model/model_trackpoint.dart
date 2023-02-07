import 'package:chaostours/file_handler.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';

class ModelTrackPoint {
  static Logger logger = Logger.logger<ModelTrackPoint>();
  static final List<ModelTrackPoint> _table = [];

  /// not yet saved active running trackpoint
  static ModelTrackPoint pendingTrackPoint = ModelTrackPoint(
      gps: GPS(0, 0),
      timeStart: DateTime.now(),
      trackPoints: <GPS>[],
      idAlias: <int>[],
      deleted: 0,
      notes: '');

  /// interval updated address of not yet saved trackPoint
  static String pendingAddressLookup = '';

  /// trackPoint stored for widgets to edit parts of it
  static ModelTrackPoint editTrackPoint = pendingTrackPoint;

  ///
  /// TrackPoint owners
  ///
  TrackingStatus status = TrackingStatus.none;

  ///
  /// Model owners
  ///
  int deleted = 0; // 0 or 1
  GPS gps;

  /// "lat,lon;lat,lon;..."
  List<GPS> trackPoints;
  DateTime timeStart;
  DateTime timeEnd = DateTime.now();

  /// "id,id,..." needs to be sorted by distance
  List<int> idAlias = [];

  /// "id,id,..." needs to be ordered by user
  List<int> idTask = [];
  String notes = '';
  late Address address;

  static int _unsavedId = 0;

  /// autoincrement unsaved models into negative ids
  static get _nextUnsavedId => --_unsavedId;
  int _id = 0;

  /// real ID<br>
  /// Is set only once during save to disk
  /// and represents the current _table.length
  int get id => _id;

  static int get length => _table.length;

  ModelTrackPoint(
      {required this.gps,
      required this.trackPoints,
      required this.idAlias,
      required this.timeStart,
      this.deleted = 0,
      this.notes = ''}) {
    _id = _nextUnsavedId;
    address = Address(gps);
  }

  static ModelTrackPoint get last => _table.last;

  String timeElapsed() {
    return util.timeElapsed(timeStart, timeEnd);
  }

  static String dump() {
    List<String> dump = [];
    for (var i in _table) {
      dump.add(i.toString());
    }
    return dump.join(FileHandler.lineSep);
  }

  /// calculates route or distance, depending on TrackingStatus status
  /// route on moving and distance on standing
  double distance() {
    if (trackPoints.isEmpty) return 0.0;
    double dist;
    if (status == TrackingStatus.standing) {
      dist = GPS.distance(trackPoints.first, trackPoints.last);
    } else {
      dist = _distanceRoute();
    }
    return (dist).round() / 1000;
  }

  // calc distance over multiple trackpoints in meters
  double _distanceRoute() {
    if (trackPoints.length < 2) return 0;
    double dist = 0;
    GPS gps = trackPoints[0];
    for (var i = 1; i < trackPoints.length; i++) {
      dist += GPS.distance(gps, trackPoints[i]);
      gps = trackPoints[i];
    }
    return dist;
  }

  ///
  /// insert only if Model doesn't have a valid (not null) _id
  /// otherwise writes table to disk
  ///
  static Future<void> insert(ModelTrackPoint m) async {
    if (m.id <= 0) {
      _table.add(m);
      m._id = _table.length;
      logger.log('Insert TrackPoint ${m.gps} which has now ID ${m._id}');
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
    if (tp.id <= 0) {
      logger.warn('Update Trackpoint forwarded to insert '
          'due to negative TrackPoint ID ${tp.id}');
      await insert(tp);
    } else {
      await write();
    }
  }

  static Future<void> write() async {
    logger.verbose('Write');
    await FileHandler.writeTable<ModelTrackPoint>(
        _table.map((e) => e.toString()).toList());
  }

  static Future<void> open() async {
    List<String> lines = await FileHandler.readTable<ModelTrackPoint>();
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
        timeStart: DateTime.parse(p[5]),
        trackPoints: parseGpsList(p[7]),
        idAlias: parseIdList(p[8]),
        notes: decode(p[10]));

    tp._id = int.parse(p[0]);
    tp.timeEnd = DateTime.parse(p[6]);
    tp.idTask = parseIdList(p[9]);
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
              .map((gps) => '${(gps.lat * 10000).round() / 10000},'
                  '${(gps.lon * 10000).round() / 10000}')
              .toList()
              .join(';')
          : '', //list.join(';'), // 7
      idAlias.join(','), // 8
      idTask.join(','), // 9
      encode(notes), // 10
      '|'
    ];
    return cols.join('\t');
  }

  /// <p><b>TSV columns: </b></p>
  /// 0 TrackingStatus index<br>
  /// 1 gps.lat<br>
  /// 2 gps.lon<br>
  /// 3 timeStart as toIso8601String<br>
  /// 4 timeEnd as above<br>
  /// 5 idAlias separated by ,<br>
  /// 6 idTask separated by ,<br>
  /// 7 notes Uri.encodeFull encoded<br>
  /// 8 lat, lon TrackPoints separated by ; and reduced to four digits<br>
  /// 9 | as line end
  String toSharedString() {
    List<String> cols = [
      status.index.toString(), // 0
      gps.lat.toString(), // 1
      gps.lon.toString(), // 2
      timeStart.toIso8601String(), // 3
      timeEnd.toIso8601String(), // 4
      idAlias.join(','), // 5
      idTask.join(','), // 6
      encode(notes), // 7
      status == TrackingStatus.moving
          ? trackPoints
              .map((gps) => '${(gps.lat * 10000).round() / 10000},'
                  '${(gps.lon * 10000).round() / 10000}')
              .toList()
              .join(';')
          : '', // 8
      '|' // 9 (secure line end)
    ];
    return cols.join('\t');
  }

  /// <p><b>TSV columns: </b></p>
  /// 0 TrackingStatus index<br>
  /// 1 gps.lat <br>
  /// 2 gps.lon<br>
  /// 3 timeStart as toIso8601String<br>
  /// 4 timeEnd as above<br>
  /// 5 idAlias separated by ,<br>
  /// 6 idTask separated by ,<br>
  /// 7 notes Uri.encodeFull encoded<br>
  /// 8 lat, lon TrackPoints separated by ; and reduced to four digits<br>
  /// 9 | as line end
  static ModelTrackPoint toSharedModel(String row) {
    List<String> p = row.split('\t');
    GPS gps = GPS(double.parse(p[1]), double.parse(p[2]));
    ModelTrackPoint model = ModelTrackPoint(
        gps: gps,
        timeStart: DateTime.parse(p[3]),
        idAlias: parseIdList(p[5]),
        trackPoints: parseGpsList(p[8]),
        deleted: 0,
        notes: decode(p[7]));
    model.status = TrackingStatus.byValue(int.parse(p[0]));
    model.idTask = parseIdList(p[6]);
    model.timeEnd = DateTime.parse(p[4]);
    return model;
  }

  //
  static List<GPS> parseGpsList(String string) {
    //return tps;
    List<String> src = string.split(';').where((e) => e.isNotEmpty).toList();
    List<GPS> gpsList = [];
    for (var item in src) {
      List<String> coords = item.split(',');
      gpsList.add(GPS(double.parse(coords[0]), double.parse(coords[1])));
    }
    return gpsList;
  }

  static List<int> parseIdList(String string) {
    string = string.trim();
    Set<int> ids = {}; // make sure they are unique
    if (string.isEmpty) return ids.toList();
    List<String> list = string.split(',');
    for (var item in list) {
      ids.add(int.parse(item));
    }
    return ids.toList();
  }
}
