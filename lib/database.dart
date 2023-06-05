import 'package:chaostours/cache.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'dart:math';
import 'package:vector_math/vector_math.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model.dart';

class AppDatabase {
  static final Logger logger = Logger.logger<AppDatabase>();

  static AppDatabase? _instance;
  factory AppDatabase() => _instance ??= AppDatabase._();

  AppDatabase._();

  static const dbFile = 'chaostours.sqlite';

  static String? _path;
  static Database? _database;

  static Future<void> deleteDb() async {
    deleteDatabase(await getPath());
  }

  /// /data/user/0/com..../databases/chaostours.sqlite
  static Future<String> getPath() async {
    var path = _path ?? await getDatabasesPath();
    path = join(path, dbFile);
    //logger.log('database path: $path');
    return path;
  }

  static Future<Database> getDatabase() async {
    return _database ??= await openDatabase(await getPath(),
        version: 1,
        singleInstance: false, onCreate: (Database db, int version) async {
      // When creating the db, create the table
      await db.execute(
          'CREATE TABLE Test (id INTEGER PRIMARY KEY, name TEXT, value INTEGER, num REAL)');
    });
  }

  static Future<void> insert(String query) async {
    var db = await getDatabase();
    await db.transaction((txn) async {
      int id1 = await txn.rawInsert(
          'INSERT INTO Test(name, value, num) VALUES("some name", 1234, 456.789)');
      logger.log('inserted1: $id1');
      int id2 = await txn.rawInsert(
          'INSERT INTO Test(name, value, num) VALUES(?, ?, ?)',
          ['another name', 12345678, 3.1416]);
      logger.log('inserted2: $id2');
    });
    db.close();
    _database = null;
  }
}

Future<String> trackpointToSql() async {
  await Cache.reload();
  await ModelTrackPoint.open();
  List<String> sql = [];
  for (var model in ModelTrackPoint.getAll()) {
    var id = model.id.toString();
    var lat = model.gps.lat.toString();
    var lon = model.gps.lon.toString();
    var start =
        (model.timeStart.millisecondsSinceEpoch / 1000).round().toString();
    var end = (model.timeEnd.millisecondsSinceEpoch / 1000).round().toString();
    var address = decode(model.address);
    sql.add('("${<String>[id, lat, lon, start, end, address].join('","')}")');
  }

  return 'INSERT INTO "trackpoint" VALUES ${sql.join('\n')}';
}

Future<String> aliasToSql() async {
  await Cache.reload();
  await ModelAlias.open();
  List<String> sql = [];
  for (var model in ModelAlias.getAll()) {
    var id = model.id.toString();
    var group = '0';
    var active = !model.deleted ? '1' : '0';
    var status = '0';
    var lat = model.lat.toString();
    var lon = model.lon.toString();
    var title = model.title;
    var description = model.notes;
    sql.add('("${<String>[
      id,
      group,
      active,
      status,
      lat,
      lon,
      title,
      description
    ].join('","')}")');
  }
  return 'INSERT INTO "alias" VALUES ${sql.join('\n')}';
}

/// written by chatGPT-4

class GpsPoint {
  double latitude;
  double longitude;

  GpsPoint(this.latitude, this.longitude);
}

List<GpsPoint> calculateSurroundingPoints(
    GpsPoint startPoint, double distance) {
  // Constants for Earth's radius in meters
  const earthRadius = 6371000.0;

  // Convert the start position to radians
  final startLatitudeRad = radians(startPoint.latitude);
  final startLongitudeRad = radians(startPoint.longitude);

  // Calculate distances in radians
  final northernDistanceRad = distance / earthRadius;
  final easternDistanceRad = distance / (earthRadius * cos(startLatitudeRad));
  final southernDistanceRad = -distance / earthRadius;
  final westernDistanceRad = -distance / (earthRadius * cos(startLatitudeRad));

  // Calculate new latitudes and longitudes
  final northernLatitude = asin(
      sin(startLatitudeRad) * cos(northernDistanceRad) +
          cos(startLatitudeRad) * sin(northernDistanceRad) * cos(0));
  final easternLongitude = startLongitudeRad +
      atan2(
          sin(0) * sin(easternDistanceRad) * cos(startLatitudeRad),
          cos(easternDistanceRad) -
              sin(startLatitudeRad) * sin(northernLatitude));
  final southernLatitude = asin(
      sin(startLatitudeRad) * cos(southernDistanceRad) +
          cos(startLatitudeRad) * sin(southernDistanceRad) * cos(0));
  final westernLongitude = startLongitudeRad +
      atan2(
          sin(0) * sin(westernDistanceRad) * cos(startLatitudeRad),
          cos(westernDistanceRad) -
              sin(startLatitudeRad) * sin(northernLatitude));

  // Convert the new latitudes and longitudes to degrees
  final northernLatitudeDeg = degrees(northernLatitude);
  final easternLongitudeDeg = degrees(easternLongitude);
  final southernLatitudeDeg = degrees(southernLatitude);
  final westernLongitudeDeg = degrees(westernLongitude);

  // Create the surrounding GPS points
  final northernPoint = GpsPoint(northernLatitudeDeg, startPoint.longitude);
  final easternPoint = GpsPoint(startPoint.latitude, easternLongitudeDeg);
  final southernPoint = GpsPoint(southernLatitudeDeg, startPoint.longitude);
  final westernPoint = GpsPoint(startPoint.latitude, westernLongitudeDeg);

  return [northernPoint, easternPoint, southernPoint, westernPoint];
/*
void test() {
  final startPoint = GpsPoint(
      52.5200, 13.4050); // Example starting point (latitude, longitude)
  const distance = 1000; // 1000 meters

  final surroundingPoints =
      calculateSurroundingPoints(startPoint, distance.toDouble());

  print(
      "Northern Point: ${surroundingPoints[0].latitude}, ${surroundingPoints[0].longitude}");
  print(
      "Eastern Point: ${surroundingPoints[1].latitude}, ${surroundingPoints[1].longitude}");
  print(
      "Southern Point: ${surroundingPoints[2].latitude}, ${surroundingPoints[2].longitude}");
  print(
      "Western Point: ${surroundingPoints[3].latitude}, ${surroundingPoints[3].longitude}");
}
*/
}
