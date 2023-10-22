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
import 'dart:io' as io;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as flite;

///
import 'package:chaostours/logger.dart';

class DB {
  static final Logger logger = Logger.logger<DB>();

  static const dbVersion = 1;
  static const dbFile = 'chaostours_$dbVersion.sqlite';
  static String? _dbFullPath;
  static flite.Database? _database;

  static Future<io.Directory> getDBDir() async {
    return io.Directory(await flite.getDatabasesPath());
  }

  /// /data/user/0/com..../databases/chaostours.sqlite
  static Future<String> getDBFilePath() async {
    _dbFullPath ??= join(await flite.getDatabasesPath(), dbFile);
    return _dbFullPath!;
  }

  static Future<void> dbToFile() async {
    var dbDir = await DB.getDBDir();
    var downloadDir = io.Directory('/storage/emulated/0/Download');
    io.File(dbDir.path).copy('${downloadDir.path}/${DB.dbFile}');
  }

  static Future<void> fileToDb() async {
    var dbDir = await DB.getDBDir();
    var downloadDir = io.Directory('/storage/emulated/0/Download');
    io.File('${downloadDir.path}/${DB.dbFile}').copy(dbDir.path);
  }

  static Future<void> openDatabase({bool create = false}) async {
    try {
      var path = await getDBFilePath();
      _database ??= await flite.openDatabase(path,
          version: dbVersion,
          singleInstance: false,
          onCreate: !create
              ? null
              : (flite.Database db, int version) async {
                  await db.transaction((txn) async {
                    var batch = txn.batch();
                    for (var sql in [
                      ...DatabaseSchema.schemata,
                      ...DatabaseSchema.indexes,
                      ...DatabaseSchema.inserts
                    ]) {
                      batch.rawQuery(sql);
                    }
                    await batch.commit();
                  });
                });
    } catch (e, stk) {
      logger.error('openDatabase: $e', stk);
      rethrow;
    }
  }

  /// <pre>
  /// // example
  ///
  /// var rows = await DB.execute<List<Map<String, Object?>>>((Transaction txn) async {
  ///    return await txn.query(...);
  ///  });
  /// </pre>
  static Future<T> execute<T>(
      Future<T> Function(flite.Transaction txn) action) async {
    // var stk = StackTrace.current;
    //try {
    if (_database == null) {
      throw 'no database set';
    }
    T result = await _database!.transaction<T>(action);
    return result;
    /*
    } catch (e, stk2) {
      logger.error('DB::execute: $e', stk);
      rethrow;
    }
    */
  }

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
    } else if (value is int) {
      return value > 0;
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

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
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

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
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

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${idTrackPoint.column}"	INTEGER NOT NULL,
	"${idUser.column}"	INTEGER NOT NULL
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableAliasAliasGroup {
  idAlias('id_alias'),
  idAliasGroup('id_alias_group');

  static const String table = 'alias_alias_group';

  static List<String> get columns =>
      TableAliasAliasGroup.values.map((e) => e.toString()).toList();

  final String column;
  const TableAliasAliasGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${idAlias.column}"	INTEGER NOT NULL,
	"${idAliasGroup.column}"	INTEGER NOT NULL
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableUserUserGroup {
  idUser('id_user'),
  idUserGroup('id_user_group');

  static const String table = 'user_user_group';

  static List<String> get columns =>
      TableUserUserGroup.values.map((e) => e.toString()).toList();

  final String column;
  const TableUserUserGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${idUser.column}"	INTEGER NOT NULL,
	"${idUserGroup.column}"	INTEGER NOT NULL
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTaskTaskGroup {
  idTask('id_task'),
  idTaskGroup('id_task_group');

  static const String table = 'task_task_group';

  static List<String> get columns =>
      TableTaskTaskGroup.values.map((e) => e.toString()).toList();

  final String column;
  const TableTaskTaskGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${idTask.column}"	INTEGER NOT NULL,
	"${idTaskGroup.column}"	INTEGER NOT NULL
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

class TableFields {
  static final List<TableFields> tables = List.unmodifiable([
    // alias
    TableFields(TableAlias.table, TableAlias.columns),
    TableFields(TableAliasAliasGroup.table, TableAliasAliasGroup.columns),
    TableFields(TableAliasGroup.table, TableAliasGroup.columns),
    // alias topic
    TableFields(TableTopic.table, TableTopic.columns),
    TableFields(TableAliasTopic.table, TableAliasTopic.columns),
    // trackpoint
    TableFields(TableTrackPoint.table, TableTrackPoint.columns),
    TableFields(TableTrackPointAlias.table, TableTrackPointAlias.columns),
    TableFields(TableTrackPointTask.table, TableTrackPointTask.columns),
    TableFields(TableTrackPointUser.table, TableTrackPointUser.columns),
    // task
    TableFields(TableTask.table, TableTask.columns),
    TableFields(TableTaskTaskGroup.table, TableTaskTaskGroup.columns),
    TableFields(TableTaskGroup.table, TableTaskGroup.columns),
    // user
    TableFields(TableUser.table, TableUser.columns),
    TableFields(TableUserUserGroup.table, TableUserUserGroup.columns),
    TableFields(TableUserGroup.table, TableUserGroup.columns),
  ]);
  final String table;
  final List<String> _columns = [];
  List<String> get columns => List.unmodifiable(_columns);

  TableFields(this.table, List<String> cols) {
    _columns.addAll(cols);
  }
}

class DatabaseSchema {
  static final List<String> schemata = [
    TableTrackPoint.schema,
    TableTrackPointAlias.schema,
    TableTrackPointTask.schema,
    TableTrackPointUser.schema,
    TableTask.schema,
    TableAlias.schema,
    TableUser.schema,
    TableTaskGroup.schema,
    TableAliasGroup.schema,
    TableUserGroup.schema,
    TableTopic.schema,
    TableAliasTopic.schema,
    TableAliasAliasGroup.schema,
    TableUserUserGroup.schema,
    TableTaskTaskGroup.schema
  ];

  static final List<String> indexes = [
    '''
CREATE INDEX IF NOT EXISTS "${TableTrackPointAlias.table}_index" ON "${TableTrackPointAlias.table}" (
	"${TableTrackPointAlias.idAlias}"	ASC,
	"${TableTrackPointAlias.idTrackPoint}" ASC
);''',
    '''
CREATE INDEX IF NOT EXISTS "${TableTrackPoint.table}_gps" ON "${TableTrackPoint.table}" (
	"${TableTrackPoint.latitude}"	ASC,
	"${TableTrackPoint.longitude}" ASC
);''',
    '''
CREATE INDEX IF NOT EXISTS "${TableAlias.table}_gps" ON "${TableAlias.table}" (
	"${TableAlias.latitude}" ASC,
	"${TableAlias.longitude}"	ASC
)''',
    '''
CREATE INDEX IF NOT EXISTS "${TableAliasAliasGroup.table}_index" ON "${TableAliasAliasGroup.table}" (
	"${TableAliasAliasGroup.idAliasGroup}" ASC,
	"${TableAliasAliasGroup.idAlias}"	ASC
)''',
    '''
CREATE INDEX IF NOT EXISTS "${TableUserUserGroup.table}_index" ON "${TableUserUserGroup.table}" (
	"${TableUserUserGroup.idUserGroup}" ASC,
	"${TableUserUserGroup.idUser}"	ASC
)''',
    '''
CREATE INDEX IF NOT EXISTS "${TableTaskTaskGroup.table}_index" ON "${TableTaskTaskGroup.table}" (
	"${TableTaskTaskGroup.idTaskGroup}" ASC,
	"${TableTaskTaskGroup.idTask}"	ASC
)'''
  ];

  static final List<String> inserts = [
    '''INSERT INTO "${TableTaskGroup.table}" VALUES (1,1,1,"Default Taskgroup",NULL)''',
    '''INSERT INTO "${TableUserGroup.table}" VALUES (1,1,1,"Default Usergroup",NULL)''',
    '''INSERT INTO "${TableAliasGroup.table}" VALUES (1,NULL,1,1,"Default Aliasgroup",NULL)''',
  ];
}
