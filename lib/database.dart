import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'package:flutter/services.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'conf/db_schema.dart';

class Insert {
  final String table;
  final Map<String, Object?> values;
  int? lastInsertId;
  Insert(this.table, this.values);
}

class AppDatabase {
  static final Logger logger = Logger.logger<AppDatabase>();

  static const dbFile = 'chaostours.sqlite';
  static const dbVersion = 1;

  static String? _path;
  static Database? _database;

  static Future<void> deleteDb() async {
    await deleteDatabase(await getPath());
  }

  static Future<void> closeDb() async {
    await _database?.close();
    _database = null;
  }

  /// /data/user/0/com..../databases/chaostours.sqlite
  static Future<String> getPath() async {
    var path = _path ?? await getDatabasesPath();
    path = join(path, dbFile);
    logger.log('database path: $path');
    return path;
  }

  static Future<Database> getDatabase() async {
    return _database ??= await openDatabase(await getPath(),
        version: dbVersion,
        singleInstance: true, onCreate: (Database db, int version) async {
      try {
        var batch = db.batch();
        for (var s in dbSchemaVersion1) {
          batch.execute(s);
        }
        batch.execute(await trackpointToSql());
        batch.execute(await aliasToSql());
        batch.execute(await userToSql());
        batch.execute(await taskToSql());
        batch.execute(await trackPointAliasToSql());
        batch.execute(await trackPointTaskToSql());
        batch.execute(await trackPointUserToSql());
        await batch.commit();
      } catch (e, stk) {
        logger.error('create database: $e', stk);
      }
    });
  }

  /// await txn.rawInsert(
  ///        'INSERT INTO Test(name, value, num) VALUES(?, ?, ?)',
  ///        ['another name', 12345678, 3.1416]);
  static Future<int> insert(Insert insert) async {
    return await _transaction<int>((txn) async {
      return await txn.insert(insert.table, insert.values);
    });
  }

  static Future<List<int>> insertMultiple(List<Insert> inserts) async {
    List<int> ids = [];
    for (var action in inserts) {
      action.lastInsertId = await insert(action);
    }
    return ids;
  }

  static Future<T> _transaction<T>(
      Future<T> Function(Transaction) action) async {
    Database db = await getDatabase();
    T result = await db.transaction<T>(action);
    await closeDb();
    return result;
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
    var address = model.address.replaceAll(RegExp('"'), '""');
    sql.add('("${<String>[id, lat, lon, start, end, address].join('","')}")');
  }

  return 'INSERT INTO "trackpoint" VALUES ${sql.join(',\n')};';
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
    var title = model.title.replaceAll(RegExp('"'), '""');
    var description = model.notes.replaceAll(RegExp('"'), '""');
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
  return 'INSERT INTO "alias" VALUES ${sql.join(',\n')};';
}

Future<String> userToSql() async {
  await Cache.reload();
  await ModelUser.open();
  List<String> sql = [];
  for (var model in ModelUser.getAll()) {
    var id = model.id.toString();
    var group = '1';
    var active = !model.deleted ? '1' : '0';
    var sort = model.sortOrder.toString();
    var phone = '';
    var address = '';
    var title = model.title.replaceAll(RegExp('"'), '""');
    var description = model.notes.replaceAll(RegExp('"'), '""');

    sql.add('("${<String>[
      id,
      group,
      active,
      sort,
      phone,
      address,
      title,
      description
    ].join('","')}")');
  }
  return 'INSERT INTO "user" VALUES ${sql.join(',\n')};';
}

Future<String> taskToSql() async {
  await Cache.reload();
  await ModelTask.open();
  List<String> sql = [];
  for (var model in ModelTask.getAll()) {
    var id = model.id.toString();
    var group = '1';
    var active = !model.deleted ? '1' : '0';
    var sort = model.sortOrder.toString();
    var title = model.title.replaceAll(RegExp('"'), '""');
    var description = model.notes.replaceAll(RegExp('"'), '""');

    sql.add('("${<String>[
      id,
      group,
      active,
      sort,
      title,
      description
    ].join('","')}")');
  }
  return 'INSERT INTO "task" VALUES ${sql.join(',\n')};';
}

Future<String> trackPointAliasToSql() async {
  await Cache.reload();
  await ModelTrackPoint.open();
  List<String> sql = [];
  for (var model in ModelTrackPoint.getAll()) {
    var tp = model.id;
    for (var id in model.idAlias) {
      sql.add('($tp,$id)');
    }
  }
  return 'INSERT INTO "trackpoint_alias" VALUES ${sql.join(',\n')};';
}

Future<String> trackPointTaskToSql() async {
  await Cache.reload();
  await ModelTrackPoint.open();
  List<String> sql = [];
  for (var model in ModelTrackPoint.getAll()) {
    var tp = model.id;
    for (var id in model.idTask) {
      sql.add('($tp,$id)');
    }
  }
  return 'INSERT INTO "trackpoint_task" VALUES ${sql.join(',\n')};';
}

Future<String> trackPointUserToSql() async {
  await Cache.reload();
  await ModelTrackPoint.open();
  List<String> sql = [];
  for (var model in ModelTrackPoint.getAll()) {
    var tp = model.id;
    for (var id in model.idUser) {
      sql.add('($tp,$id)');
    }
  }
  return 'INSERT INTO "trackpoint_user" VALUES ${sql.join(',\n')};';
}

/// written by chatGPT-4

/// based on ChatGPT-4 response
GpsArea calculateSurroundingPoints(
    {required double latitude,
    required double longitude,
    required double distance}) {
  // Constants for Earth's radius in meters
  const earthRadius = 6371000.0;

  // Convert the start position to radians
  final startLatitudeRad = radians(latitude);
  final startLongitudeRad = radians(longitude);

  // Calculate distances in radians
  final latDistanceRad = distance / earthRadius;
  final lonDistanceRad = distance / (earthRadius * cos(startLatitudeRad));

  // Calculate new latitudes and longitudes
  final northernLatitude = asin(sin(startLatitudeRad) * cos(latDistanceRad) +
      cos(startLatitudeRad) * sin(latDistanceRad) * cos(0));
  final southernLatitude = asin(sin(startLatitudeRad) * cos(latDistanceRad) +
      cos(startLatitudeRad) * sin(latDistanceRad) * cos(180));

  final easternLongitude = startLongitudeRad +
      atan2(sin(lonDistanceRad) * cos(startLatitudeRad),
          cos(latDistanceRad) - sin(startLatitudeRad) * sin(northernLatitude));
  final westernLongitude = startLongitudeRad -
      atan2(sin(lonDistanceRad) * cos(startLatitudeRad),
          cos(latDistanceRad) - sin(startLatitudeRad) * sin(southernLatitude));

  // Convert the new latitudes and longitudes to degrees
  final northernLatitudeDeg = degrees(northernLatitude);
  final easternLongitudeDeg = degrees(easternLongitude);
  final southernLatitudeDeg = degrees(southernLatitude);
  final westernLongitudeDeg = degrees(westernLongitude);

  // Create the surrounding GPS points
  final north = GPS(northernLatitudeDeg, longitude);
  final east = GPS(latitude, easternLongitudeDeg);
  final south = GPS(southernLatitudeDeg, longitude);
  final west = GPS(latitude, westernLongitudeDeg);

  return GpsArea(north: north, east: east, south: south, west: west);
  /*

calculateSurroundingPoints(GpsPoint(50, 30), 1000.0);

Northern Point: 50.008993216059196, 30
Eastern Point: 50, 30.021770141923543
Southern Point: 49.99100678394081, 30
Western Point: 50, 29.978238001159266



*/
}

void test() {
  final area =
      calculateSurroundingPoints(latitude: 50, longitude: 30, distance: 1000.0);

  print("Northern Point: ${area.north.lat}, ${area.north.lon}");
  print("Eastern Point: ${area.east.lat}, ${area.east.lon}");
  print("Southern Point: ${area.south.lat}, ${area.south.lon}");
  print("Western Point: ${area.west.lat}, ${area.west.lon}");
}
