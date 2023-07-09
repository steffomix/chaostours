/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as flite;

///
import 'package:chaostours/logger.dart';

class DB {
  /// <pre>
  /// var result = await query<T>((Transaction txn) async {
  ///   return await txn...;
  /// });
  ///
  /// </pre>
  static var execute = _AppDatabase._query;

  static Future<String> getPath = _AppDatabase.getPath();

  static bool closeDb = false;

  static int parseInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    } else if (value is String) {
      try {
        return int.parse(value.trim());
      } catch (e) {
        return fallback;
      }
    } else {
      return fallback;
    }
  }

  static double parseDouble(Object? value, {double fallback = 0.0}) {
    if (value is double) {
      return value;
    } else if (value is String) {
      try {
        return double.parse(value.trim());
      } catch (e) {
        return fallback;
      }
    } else {
      return fallback;
    }
  }

  static String parseString(Object? text, {fallback = ''}) {
    if (text is String) {
      return text;
    }
    if (text == null) {
      return fallback;
    }
    return text.toString();
  }

  static bool parseBool(Object? value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    } else if (value is String) {
      try {
        return int.parse(value.toString()) > 0;
      } catch (e) {
        return fallback;
      }
    } else {
      return fallback;
    }
  }

  static int boolToInt(bool b) => b ? 1 : 0;

  static int timeToInt(DateTime time) {
    return (time.millisecondsSinceEpoch / 1000).round();
  }

  static DateTime intToTime(Object? i) {
    return DateTime.fromMillisecondsSinceEpoch(parseInt(i) * 1000);
  }
}

class _AppDatabase {
  static final Logger logger = Logger.logger<_AppDatabase>();

  static const dbFile = 'chaostours.sqlite';
  static const dbVersion = 1;

  static String? _path;
  static flite.Database? _database;

  static Future<void> _closeDb() async {
    await _database?.close();
    _database = null;
  }

  /// /data/user/0/com..../databases/chaostours.sqlite
  static Future<String> getPath() async {
    var path = _path ?? await flite.getDatabasesPath();
    path = join(path, dbFile);
    logger.log('database path: $path');
    return path;
  }

  static Future<flite.Database> _getDatabase() async {
    return _database ??= await flite.openDatabase(await getPath(),
        version: dbVersion,
        singleInstance: false,
        onCreate: (flite.Database db, int version) async {});
  }

  /// ```dart
  /// var result = await query<ExpectedType>((Transaction txn){
  ///   ExpectedType result await txn...;
  ///   return result;
  /// });
  ///
  /// ```
  static Future<T> _query<T>(
      Future<T> Function(flite.Transaction txn) action) async {
    flite.Database db = await _getDatabase();
    T result = await db.transaction<T>(action);
    if (DB.closeDb) {
      await _closeDb();
    }
    return result;
  }
}

///
///
///
/// schemata
///
///
///

enum TableTrackPoint {
  id('id'),
  latitude('latitude'),
  longitude('longitude'),
  timeStart('datetime_start'),
  timeEnd('datetime_end'),
  address('address'),
  notes('notes');

  static const String table = 'trackpoint';

  static TableTrackPoint get primaryKey {
    return id;
  }

  static List<String> get columns =>
      TableTrackPoint.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPoint(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${latitude.column}"	NUMERIC NOT NULL,
	"${longitude.column}"	NUMERIC NOT NULL,
	"${timeStart.column}"	TEXT NOT NULL,
	"${timeEnd.column}"	TEXT NOT NULL,
	"${address.column}"	TEXT,
	"${notes.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
  );;
''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPointAlias {
  idTrackPoint('id_trackpoint'),
  idAlias('id_alias');

  static const String table = 'trackpoint_alias';

  static List<String> get columns =>
      TableTrackPointAlias.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPointAlias(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "trackpoint_alias" (
	"${idTrackPoint.column}"	INTEGER NOT NULL,
	"${idAlias.column}"	INTEGER NOT NULL
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPointTask {
  idTrackPoint('id_trackpoint'),
  idTask('id_task');

  static const String table = 'trackpoint_task';

  static List<String> get columns =>
      TableTrackPointTask.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPointTask(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "trackpoint_task" (
	"${idTrackPoint.column}"	INTEGER NOT NULL,
	"${idTask.column}"	INTEGER NOT NULL
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPointUser {
  idTrackPoint('id_trackpoint'),
  idUser('id_user');

  static const String table = 'trackpoint_user';

  static List<String> get columns =>
      TableTrackPointUser.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPointUser(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "trackpoint_user" (
	"${idTrackPoint.column}"	INTEGER NOT NULL,
	"${idUser.column}"	INTEGER NOT NULL
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTask {
  id('id'),
  idTaskGroup('id_task_group'),
  isActive('active'),
  sortOrder('sort'),
  title('title'),
  description('description');

  static const String table = 'task';

  static List<String> get columns =>
      TableTask.values.map((e) => e.toString()).toList();

  static TableTask get primaryKey {
    return id;
  }

  final String column;
  const TableTask(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${idTaskGroup.column}"	INTEGER NOT NULL DEFAULT 1,
	"${isActive.column}"	INTEGER DEFAULT 1,
	"${sortOrder.column}"	INTEGER DEFAULT 1,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableAlias {
  id('id'),
  idAliasGroup('id_alias_group'),
  isActive('active'),
  calendarId('calendar_id'),
  radius('radius'),
  visibility('visibilty'),
  lastVisited('last_visited'),
  timesVisited('times_visited'),
  latitude('latitude'),
  longitude('longitude'),
  title('title'),
  description('description');

  static const String table = 'alias';

  static List<String> get columns =>
      TableAlias.values.map((e) => e.toString()).toList();

  static TableAlias get primaryKey {
    return id;
  }

  final String column;
  const TableAlias(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${idAliasGroup.column}"	INTEGER NOT NULL DEFAULT 1,
	"${isActive.column}"	INTEGER,
  "${calendarId.column}" TEXT,
  "${radius.column}" INTEGER,
	"${visibility.column}"	INTEGER,
	"${latitude.column}"	NUMERIC NOT NULL,
	"${longitude.column}"	NUMERIC NOT NULL,
	"${lastVisited.column}"	TEXT,
	"${timesVisited.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableUser {
  id('id'),
  idUserGroup('id_user_group'),
  isActive('active'),
  sortOrder('sort'),
  phone('phone'),
  address('address'),
  title('title'),
  description('description');

  static const String table = 'user';

  static List<String> get columns =>
      TableUser.values.map((e) => e.toString()).toList();

  static TableUser get primaryKey {
    return id;
  }

  final String column;
  const TableUser(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${idUserGroup.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${phone.column}"	TEXT,
	"${address.column}"	TEXT,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTaskGroup {
  id('id'),
  isActive('active'),
  visibility('visibility'),
  sortOrder('sort'),
  title('title'),
  description('description');

  static const String table = 'task_group';

  static List<String> get columns =>
      TableTaskGroup.values.map((e) => e.toString()).toList();

  static TableTaskGroup get primaryKey {
    return id;
  }

  final String column;
  const TableTaskGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${visibility.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableUserGroup {
  id('id'),
  isActive('active'),
  sortOrder('sort'),
  title('title'),
  description('description');

  static const String table = 'user_group';

  static List<String> get columns =>
      TableUserGroup.values.map((e) => e.toString()).toList();

  static TableUserGroup get primaryKey {
    return id;
  }

  final String column;
  const TableUserGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableAliasTopic {
  idAlias('id_alias'),
  idTopic('id_topic');

  static const String table = 'alias_topic';

  final String column;
  const TableAliasTopic(this.column);

  static List<String> get columns =>
      TableAliasTopic.values.map((e) => e.toString()).toList();

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${idAlias.column}"	INTEGER,
	"${idTopic.column}"	INTEGER
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTopic {
  id('id'),
  isActive('active'),
  sortOrder('sort'),
  title('title'),
  description('description');

  static const String table = 'topic';

  static List<String> get columns =>
      TableTopic.values.map((e) => e.toString()).toList();

  static TableTopic get primaryKey {
    return id;
  }

  final String column;
  const TableTopic(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableAliasGroup {
  id('id'),
  idCalendar('id_calendar'),
  isActive('active'),
  visibility('sort'),
  title('title'),
  description('description');

  static const String table = 'alias_group';

  static List<String> get columns =>
      TableAliasGroup.values.map((e) => e.toString()).toList();

  static TableAliasGroup get primaryKey {
    return id;
  }

  final String column;
  const TableAliasGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${primaryKey.column}"	INTEGER NOT NULL,
	"${idCalendar.column}"	TEXT,
	"${isActive.column}"	INTEGER,
	"${visibility.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${primaryKey.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

class DatabaseSchema {
  static final List<String> schemata = [
    /// trackPoint
    TableTrackPoint.schema,
    TableTrackPointTask.schema,
    TableTrackPointAlias.schema,
    TableTrackPointUser.schema,

    /// alias
    TableAlias.schema,
    TableAliasGroup.schema,
    TableAliasTopic.schema,

    /// task
    TableTask.schema,
    TableTaskGroup.schema,

    /// user
    TableUser.schema,
    TableUserGroup.schema,
  ];

  static final List<String> indexes = [
    '''
CREATE INDEX IF NOT EXISTS "${TableTrackPoint.table}_gps" ON "${TableTrackPoint.table}" (
	"${TableTrackPoint.latitude}"	ASC,
	"${TableTrackPoint.longitude}"	ASC
);''',
    '''
CREATE INDEX IF NOT EXISTS "${TableAlias.table}_gps" ON "${TableAlias.table}" (
	"${TableAlias.latitude}"	ASC,
	"${TableAlias.longitude}"	ASC
)'''
  ];

  static final List<String> inserts = [
    '''INSERT INTO "${TableTaskGroup.table}" VALUES (1,1,1,"Default Taskgroup",NULL)''',
    '''INSERT INTO "${TableUserGroup.table}" VALUES (1,1,1,"Default Usergroup",NULL)''',
    '''INSERT INTO "${TableAliasGroup.table}" VALUES (1,1,1,"Default Aliasgroup",NULL)''',
  ];
}

List<String> dbSchemaVersion1 = [
  '''
CREATE TABLE IF NOT EXISTS "trackpoint" (
	"id"	INTEGER NOT NULL,
	"latitude"	NUMERIC NOT NULL,
	"longitude"	NUMERIC NOT NULL,
	"datetime_start"	TEXT NOT NULL,
	"datetime_end"	TEXT NOT NULL,
	"address"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
CREATE TABLE IF NOT EXISTS "trackpoint_alias" (
	"id_trackpoint"	INTEGER NOT NULL,
	"id_alias"	INTEGER NOT NULL
)''',
  '''
CREATE TABLE IF NOT EXISTS "trackpoint_task" (
	"id_trackpoint"	INTEGER NOT NULL,
	"id_task"	INTEGER NOT NULL
)''',
  '''
CREATE TABLE IF NOT EXISTS "trackpoint_user" (
	"id_trackpoint"	INTEGER NOT NULL,
	"id_user"	INTEGER NOT NULL
)''',
  '''
CREATE TABLE IF NOT EXISTS "task" (
	"id"	INTEGER NOT NULL,
	"id_task_group"	INTEGER NOT NULL DEFAULT 1,
	"active"	INTEGER DEFAULT 1,
	"sort"	INTEGER DEFAULT 1,
	"title"	TEXT NOT NULL,
	"description"	TEXT NOT NULL,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
CREATE TABLE IF NOT EXISTS "alias" (
	"id"	INTEGER NOT NULL,
	"id_alias_group"	INTEGER NOT NULL,
	"active"	INTEGER,
	"visibilty"	INTEGER,
	"latitude"	NUMERIC NOT NULL,
	"longitude"	NUMERIC NOT NULL,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
CREATE TABLE IF NOT EXISTS "user" (
	"id"	INTEGER NOT NULL,
	"id_user_group"	INTEGER NOT NULL,
	"active"	INTEGER,
	"sort"	INTEGER,
	"phone"	TEXT,
	"address"	TEXT,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
CREATE TABLE IF NOT EXISTS "task_group" (
	"id"	INTEGER NOT NULL,
	"active"	INTEGER,
	"sort"	INTEGER,
	"title"	INTEGER,
	"description"	INTEGER,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
CREATE TABLE IF NOT EXISTS "user_group" (
	"id"	INTEGER NOT NULL,
	"active"	INTEGER,
	"sort"	INTEGER,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
CREATE TABLE IF NOT EXISTS "alias_topic" (
	"id_alias"	INTEGER,
	"id_topic"	INTEGER
)''',
  '''
CREATE TABLE IF NOT EXISTS "topic" (
	"id"	INTEGER NOT NULL,
	"sort"	INTEGER,
	"title"	TEXT NOT NULL UNIQUE,
	"description"	INTEGER,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
CREATE TABLE IF NOT EXISTS "alias_group" (
	"id"	INTEGER NOT NULL,
	"active"	INTEGER,
	"visibility"	INTEGER,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
)''',
  '''
INSERT INTO "task_group" VALUES (1,1,1,"Default Taskgroup",NULL)''',
  '''
INSERT INTO "user_group" VALUES (1,1,1,"Default Usergroup",NULL)''',
  '''
INSERT INTO "alias_group" VALUES (1,1,1,"Default Aliasgroup",NULL)''',
  '''
CREATE INDEX IF NOT EXISTS "trackpoint_latitude_longitude" ON "trackpoint" (
	"latitude"	ASC,
	"longitude"	ASC
)''',
  '''
CREATE INDEX IF NOT EXISTS "alias_latitude_longitude" ON "alias" (
	"latitude"	ASC,
	"longitude"	ASC
)'''
];

/*

/// old tsv to sql

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

*/
