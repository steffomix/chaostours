/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the License);
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an AS IS BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'dart:async';
import 'dart:io' as io;
import 'dart:io';
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/database/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as flite;
import 'package:chaostours/util.dart' show returnDelayed;

///
import 'package:chaostours/logger.dart';

class DB {
  static final Logger logger = Logger.logger<DB>();

  static const dbVersion = 1;
  static const dbFile = 'chaostours_database_v$dbVersion.sqlite';
  static String? _dbFullPath;
  static flite.Database? _database;

  // lock unlock for import export operations
  static bool _isClosed = true;
  static bool _isClosedPermanently = false;

  static Future<io.Directory> getDBDir() async {
    return io.Directory(await flite.getDatabasesPath());
  }

  /// /data/user/0/com..../databases/chaostours.sqlite
  static Future<String> getDBFullPath() async {
    _dbFullPath ??= join(await flite.getDatabasesPath(), dbFile);
    return _dbFullPath!;
  }

  static Future<flite.Database> openDatabase({bool create = false}) async {
    if (_isClosedPermanently) {
      throw 'Database has been closed an can not be opened again. Restart App instead.';
    }
    _isClosed = false;
    try {
      var path = await getDBFullPath();
      return await flite.openDatabase(path,
          version: dbVersion,
          singleInstance: true,
          onCreate: !create
              ? null
              : (flite.Database db, int version) async {
                  try {
                    await db.transaction((txn) async {
                      try {
                        var batch = txn.batch();
                        for (var sql in [
                          ...DbTable.tables.map((e) => e.schema),
                          ...DbTable.indexes,
                          ...DbTable.inserts
                        ]) {
                          batch.rawQuery(sql);
                        }
                        await batch.commit();
                      } catch (e, stk) {
                        logger.fatal('Execute Batch create Database: $e', stk);
                        rethrow;
                      }
                    });
                  } catch (e, stk) {
                    logger.fatal('Create Database: $e', stk);
                    rethrow;
                  }
                });
    } catch (e, stk) {
      logger.error('openDatabase: $e', stk);
      rethrow;
    }
  }

  static Future<void> closeDatabase() async {
    _isClosedPermanently = _isClosed = true;
    await _database?.close();
  }

  static Stream<Widget> exportDatabase(String target,
      {Function()? onSuccess, Function()? onError}) async* {
    try {
      String dbPath = await DB.getDBFullPath();
      File dbFile = File(dbPath);

      if (await File(target).exists()) {
        yield await returnDelayed(Text('File already exist: $target'));
        yield await returnDelayed(const Text('Cancel Export'));
        onError?.call();
        return;
      }

      bool channelIsRunning = await BackgroundChannel.isRunning();
      if (channelIsRunning) {
        yield await returnDelayed(const Text('Stop Background Channel'));
        await BackgroundChannel.stop();
      }

      yield await returnDelayed(const Text('Close Database'));
      BackgroundChannel.invoke(BackgroundChannelCommand.closeDatabase);
      await DB.closeDatabase();

      yield await returnDelayed(Text('Copy Database to $target'));
      await dbFile.copy(target);

      yield await returnDelayed(Center(
          child: FilledButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text('Export finished. Shutting down App...'))));
    } catch (e, stk) {
      yield await returnDelayed(Text('Import Error: $e'));
      logger.error('import db.sqlite: $e', stk);
      onError?.call();
    }
    onSuccess?.call();
  }

  static Stream<Widget> importDatabase(String path,
      {Function()? onSuccess, Function()? onError}) async* {
    try {
      String target = await getDBFullPath();
      File file = File(path);
      if (!file.existsSync()) {
        yield await returnDelayed(Text('File not found: $path'));
        yield await returnDelayed(const Text('Import canceled.'));
        onError?.call();
        return;
      }
      bool channelIsRunning = await BackgroundChannel.isRunning();
      if (channelIsRunning) {
        yield await returnDelayed(const Text('Stop Background Channel'));
        await BackgroundChannel.stop();
      }

      yield await returnDelayed(const Text('Lock Database'));
      DB._isClosed = true;

      yield await returnDelayed(const Text('Close Database'));
      await DB.closeDatabase();

      yield await returnDelayed(Text('Copy Database to $target'));
      await file.copy(await DB.getDBFullPath());

      /// set trigger for calendar prompt on app boot
      await Cache.databaseImportedCalendarDisabled.save<bool>(true);

      yield await returnDelayed(Center(
          child: FilledButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text('Export finished. Restarting App...'))));
    } catch (e, stk) {
      yield await returnDelayed(Text('Import Error: $e'));
      logger.error('import db.sqlite: $e', stk);
      onError?.call();
    }
    onSuccess?.call();
  }

  static Stream<Widget> deleteDatabase(
      {Function()? onSuccess, Function()? onError}) async* {
    yield await returnDelayed(Text('Delete Database: ${getDBFullPath()}'));
    try {
      File file = File(await getDBFullPath());
      file.deleteSync();
      yield await returnDelayed(const Text('Database deleted.'));
      yield await returnDelayed(
          const Text('A brand new one will be created on restart.'));
    } catch (e) {
      yield await returnDelayed(Text('Error Reset Database: $e'));
      onError?.call();
    }
    onSuccess?.call();
  }

  static Future<T> execute<T>(
      Future<T> Function(flite.Transaction txn) action) async {
    while (_isClosed) {
      logger.warn('Database is closed for import-export operations');
      await Future.delayed(const Duration(seconds: 1));
    }
    return await (_database ??= await openDatabase()).transaction<T>(action);
  }
}

enum CacheData {
  id('sort'),
  key('key'),
  data('data');

  static const String table = 'cache_data';

  static List<String> get columns =>
      CacheData.values.map((e) => e.toString()).toList();

  final String column;
  const CacheData(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${id.column}	INTEGER NOT NULL,
	${key.column}	TEXT NOT NULL,
	${data.column}	TEXT)''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPoint {
  id('id'),
  isActive('active'),
  latitude('latitude'),
  longitude('longitude'),
  timeStart('datetime_start'),
  timeEnd('datetime_end'),
  address('address'),
  fullAddress('fullAddress'),
  notes('notes');

  static const String table = 'trackpoint';

  static TableTrackPoint get primaryKey {
    return id;
  }

  static List<String> get columns =>
      TableTrackPoint.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPoint(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column}	INTEGER NOT NULL,
  ${isActive.column} INTEGER DEFAULT 1,
	${latitude.column}	NUMERIC NOT NULL,
	${longitude.column}	NUMERIC NOT NULL,
	${timeStart.column}	INTEGER NOT NULL,
	${timeEnd.column}	INTEGER NOT NULL,
	${address.column}	TEXT,
	${fullAddress.column}	TEXT,
	${notes.column}	TEXT,
	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPointLocation {
  idTrackPoint('id_trackpoint'),
  idLocation('id_location'),
  notes('notes');

  static const String table = 'trackpoint_location';

  static List<String> get columns =>
      TableTrackPointLocation.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPointLocation(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idTrackPoint.column}	INTEGER NOT NULL,
	${idLocation.column}	INTEGER NOT NULL,
  ${notes.column} Text)''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPointTask {
  idTrackPoint('id_trackpoint'),
  idTask('id_task'),
  notes('notes');

  static const String table = 'trackpoint_task';

  static List<String> get columns =>
      TableTrackPointTask.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPointTask(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idTrackPoint.column}	INTEGER NOT NULL,
	${idTask.column}	INTEGER NOT NULL,
  ${notes.column} Text)''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPointUser {
  idTrackPoint('id_trackpoint'),
  idUser('id_user'),
  notes('notes');

  static const String table = 'trackpoint_user';

  static List<String> get columns =>
      TableTrackPointUser.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPointUser(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idTrackPoint.column}	INTEGER NOT NULL,
	${idUser.column}	INTEGER NOT NULL,
  ${notes.column} Text)''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTrackPointCalendar {
  idTrackPoint('id_trackpoint'),
  idLocationGroup('id_location_group'),
  idCalendar('id_calendar'),
  idEvent('id_event'),
  title('title'),
  body('body');

  static const String table = 'trackpoint_calendar';

  static List<String> get columns =>
      TableTrackPointCalendar.values.map((e) => e.toString()).toList();

  final String column;
  const TableTrackPointCalendar(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idTrackPoint.column}	INTEGER NOT NULL,
	${idLocationGroup.column}	INTEGER NOT NULL,
	${idCalendar.column}	TEXT,
	${idEvent.column}	TEXT,
	${title.column}	TEXT,
	${body.column} TEXT,
  PRIMARY KEY(${idTrackPoint.column}, ${idLocationGroup.column}))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableLocationLocationGroup {
  idLocation('id_location'),
  idLocationGroup('id_location_group');

  static const String table = 'location_location_group';

  static List<String> get columns =>
      TableLocationLocationGroup.values.map((e) => e.toString()).toList();

  final String column;
  const TableLocationLocationGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idLocation.column}	INTEGER NOT NULL,
	${idLocationGroup.column}	INTEGER NOT NULL)''';

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

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idUser.column}	INTEGER NOT NULL,
	${idUserGroup.column}	INTEGER NOT NULL)''';

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

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idTask.column}	INTEGER NOT NULL,
	${idTaskGroup.column}	INTEGER NOT NULL)''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTask {
  id('id'),
  isActive('active'),
  isSelectable('selectable'),
  isPreselected('preselected'),
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

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column}	INTEGER NOT NULL,
	${isActive.column}	INTEGER DEFAULT 1,
	${isSelectable.column}	INTEGER DEFAULT 1,
	${isPreselected.column}	INTEGER DEFAULT 0,

	${sortOrder.column}	TEXT,
	${title.column}	TEXT NOT NULL,
	${description.column}	TEXT,
	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableLocation {
  id('id'),
  isActive('active'),
  radius('radius'),
  privacy('privacy'),
  latitude('latitude'),
  longitude('longitude'),
  title('title'),
  description('description');

  static const String table = 'location';

  static List<String> get columns =>
      TableLocation.values.map((e) => e.toString()).toList();

  static TableLocation get primaryKey {
    return id;
  }

  final String column;
  const TableLocation(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column}	INTEGER NOT NULL,
	${isActive.column}	INTEGER DEFAULT 1,
  ${radius.column} INTEGER,
	${privacy.column}	INTEGER,
	${latitude.column}	NUMERIC NOT NULL,
	${longitude.column}	NUMERIC NOT NULL,
	${title.column}	TEXT,
	${description.column}	TEXT,
	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableUser {
  id('id'),
  isActive('active'),
  isSelectable('selectable'),
  isPreselected('preselected'),
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

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column}	INTEGER NOT NULL,
	${isActive.column}	INTEGER DEFAULT 1,
	${isSelectable.column}	INTEGER DEFAULT 1,
	${isPreselected.column}	INTEGER DEFAULT 0,
	${sortOrder.column}	TEXT,
	${phone.column}	TEXT,
	${address.column}	TEXT,
	${title.column}	TEXT,
	${description.column}	TEXT,
	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableTaskGroup {
  id('id'),
  isActive('active'),
  isSelectable('selectable'),
  isPreselected('preselected'),
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

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column} INTEGER NOT NULL,
	${isActive.column} INTEGER DEFAULT 1,
	${isSelectable.column} INTEGER DEFAULT 1,
	${isPreselected.column} INTEGER DEFAULT 0,
	${sortOrder.column}	TEXT,
	${title.column}	TEXT NOT NULL,
	${description.column}	TEXT,
	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableUserGroup {
  id('id'),
  isActive('active'),
  isSelectable('selectable'),
  isPreselected('preselected'),
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

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column}	INTEGER NOT NULL,
	${isActive.column}	INTEGER DEFAULT 1,
	${isSelectable.column} INTEGER DEFAULT 1,
	${isPreselected.column} INTEGER DEFAULT 0,
	${sortOrder.column}	TEXT,
	${title.column}	TEXT,
	${description.column}	TEXT,
	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableLocationTopic {
  idLocation('id_location'),
  idTopic('id_topic');

  static const String table = 'location_topic';

  final String column;
  const TableLocationTopic(this.column);

  static List<String> get columns =>
      TableLocationTopic.values.map((e) => e.toString()).toList();

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${idLocation.column}	INTEGER,
	${idTopic.column}	INTEGER)''';

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

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column}	INTEGER NOT NULL,
	${isActive.column}	INTEGER DEFAULT 1,
	${sortOrder.column}	TEXT,
	${title.column}	TEXT,
	${description.column}	TEXT,
	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableLocationGroup {
  id('id'),
  idCalendar('id_calendar'),
  isActive('active'),
  privacy('sort'),
  title('title'),
  description('description'),

  withCalendarHtml('calendar_html'),

  withCalendarTimeStart('calendar_time_start'),
  withCalendarTimeEnd('calendar_time_end'),
  withCalendarAllDay('calendar_all_day'),
  withCalendarDuration('calendar_duration'),

  withCalendarLocation('calendar_location'),
  withCalendarLocationNearby('calendar_location_nearby'),
  withCalendarLocationDescription('calendar_location_description'),
  withCalendarNearbyLocationDescription('calendar_nearby_location_description'),

  withCalendarGps('calendar_gps'),
  withCalendarAddress('calendar_address'),
  withCalendarFullAddress('calendar_full_address'),

  withCalendarTrackpointNotes('calendar_trackpoint_notes'),

  withCalendarTasks('calendar_tasks'),
  withCalendarTaskNotes('calendar_task_notes'),
  withCalendarTaskDescription('calendar_task_description'),

  withCalendarUsers('calendar_users'),
  withCalendarUserNotes('calendar_user_notes'),
  withCalendarUserDescription('calendar_user_description'),
  ;

  static List<TableLocationGroup> calendarFields() {
    return TableLocationGroup.values
        .where(
          (e) => e.name.contains('withCalendar'),
        )
        .toList();
  }

  static const String table = 'location_group';

  static List<String> get columns =>
      TableLocationGroup.values.map((e) => e.toString()).toList();

  static TableLocationGroup get primaryKey {
    return id;
  }

  final String column;
  const TableLocationGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS $table (
	${primaryKey.column} INTEGER NOT NULL,
	${idCalendar.column} TEXT,
	${isActive.column} INTEGER DEFAULT 1,
	${privacy.column} INTEGER,
	${title.column} TEXT,
	${description.column} TEXT,

  ${withCalendarHtml.column} INTEGER,

  ${withCalendarTimeStart.column}	INTEGER,
  ${withCalendarTimeEnd.column}	INTEGER,
  ${withCalendarAllDay.column}	INTEGER,
  ${withCalendarDuration.column} INTEGER,

  ${withCalendarLocation.column}	INTEGER,
  ${withCalendarLocationNearby.column}	INTEGER,
  ${withCalendarLocationDescription.column} INTEGER,
  ${withCalendarNearbyLocationDescription.column} INTEGER,

  ${withCalendarGps.column} INTEGER,
  ${withCalendarAddress.column}	INTEGER,
  ${withCalendarFullAddress.column}	INTEGER,

  ${withCalendarTrackpointNotes.column}	INTEGER,

  ${withCalendarTasks.column}	INTEGER,
  ${withCalendarTaskNotes.column}	INTEGER,
  ${withCalendarTaskDescription.column}	INTEGER,
  
  ${withCalendarUsers.column}	INTEGER,
  ${withCalendarUserNotes.column}	INTEGER,
  ${withCalendarUserDescription.column}	INTEGER,

	PRIMARY KEY(${primaryKey.column} AUTOINCREMENT))''';

  @override
  String toString() {
    return '$table.$column';
  }
}

class DbTable {
  static final List<DbTable> tables = List.unmodifiable([
    // location
    DbTable(TableLocation.table, TableLocation.columns, TableLocation.schema),
    DbTable(TableLocationLocationGroup.table,
        TableLocationLocationGroup.columns, TableLocationLocationGroup.schema),
    DbTable(TableLocationGroup.table, TableLocationGroup.columns,
        TableLocationGroup.schema),
    // location topic
    DbTable(TableTopic.table, TableTopic.columns, TableTopic.schema),
    DbTable(TableLocationTopic.table, TableLocationTopic.columns,
        TableLocationTopic.schema),
    // trackpoint
    DbTable(
        TableTrackPoint.table, TableTrackPoint.columns, TableTrackPoint.schema),
    DbTable(TableTrackPointLocation.table, TableTrackPointLocation.columns,
        TableTrackPointLocation.schema),
    DbTable(TableTrackPointTask.table, TableTrackPointTask.columns,
        TableTrackPointTask.schema),
    DbTable(TableTrackPointUser.table, TableTrackPointUser.columns,
        TableTrackPointUser.schema),
    DbTable(TableTrackPointCalendar.table, TableTrackPointCalendar.columns,
        TableTrackPointCalendar.schema),
    // task
    DbTable(TableTask.table, TableTask.columns, TableTask.schema),
    DbTable(TableTaskTaskGroup.table, TableTaskTaskGroup.columns,
        TableTaskTaskGroup.schema),
    DbTable(
        TableTaskGroup.table, TableTaskGroup.columns, TableTaskGroup.schema),
    // user
    DbTable(TableUser.table, TableUser.columns, TableUser.schema),
    DbTable(TableUserUserGroup.table, TableUserUserGroup.columns,
        TableUserUserGroup.schema),
    DbTable(
        TableUserGroup.table, TableUserGroup.columns, TableUserGroup.schema),

    //DbTable(CacheData.table, CacheData.columns, CacheData.schema),
  ]);
  final String table;
  final String schema;
  final List<String> _columns = [];
  List<String> get columns => List.unmodifiable(_columns);

  DbTable(this.table, List<String> cols, this.schema) {
    _columns.addAll(cols);
  }

  static final List<String> indexes = [
    ///
    /// GPS
    ///
    '''CREATE INDEX IF NOT EXISTS index_gps_${TableTrackPoint.table} ON ${TableTrackPoint.table} (
	${TableTrackPoint.latitude.column}	ASC,
	${TableTrackPoint.longitude.column} ASC)''',

    '''CREATE INDEX IF NOT EXISTS index_gps_${TableLocation.table} ON ${TableLocation.table} (
	${TableLocation.latitude.column} ASC,
	${TableLocation.longitude.column}	ASC)''',

    /// calendar to trackpoint
    /// ***not unique!***, calendar ids are text and can change unpredectable)
    /// make a clean query on boot instead to remove doubles
    /*
    keep the last insert with max(rowid)
    delete from *table* where rowid not in 
      (select max(rowid) from *table* group by *table*.column1, *table*.column2 [,...])

    https://stackoverflow.com/a/8190671/4823385
    */
    '''CREATE INDEX IF NOT EXISTS index_${TableTrackPointCalendar.table}_${TableTrackPointCalendar.table} ON ${TableTrackPointCalendar.table} (
	${TableTrackPointCalendar.idCalendar.column}	ASC,
	${TableTrackPointCalendar.idTrackPoint.column} ASC)''',

    ///
    /// asset to trackpoint
    ///
    '''CREATE UNIQUE INDEX IF NOT EXISTS index_${TableTrackPointLocation.table}_${TableTrackPointLocation.table} ON ${TableTrackPointLocation.table} (
	${TableTrackPointLocation.idLocation.column}	ASC,
	${TableTrackPointLocation.idTrackPoint.column} ASC)''',

    '''CREATE UNIQUE INDEX IF NOT EXISTS index_${TableTrackPointUser.table}_${TableTrackPointUser.table} ON ${TableTrackPointUser.table} (
	${TableTrackPointUser.idUser.column}	ASC,
	${TableTrackPointUser.idTrackPoint.column} ASC)''',

    '''CREATE UNIQUE INDEX IF NOT EXISTS index_${TableTrackPointTask.table}_${TableTrackPointTask.table} ON ${TableTrackPointTask.table} (
	${TableTrackPointTask.idTask.column}	ASC,
	${TableTrackPointTask.idTrackPoint.column} ASC)''',

    ///
    /// asset to group
    ///
    '''CREATE UNIQUE INDEX IF NOT EXISTS index_${TableLocation.table}_${TableLocationGroup.table} ON ${TableLocationLocationGroup.table} (
	${TableLocationLocationGroup.idLocation.column}	ASC,
	${TableLocationLocationGroup.idLocationGroup.column} ASC)''',

    '''CREATE UNIQUE INDEX IF NOT EXISTS index_${TableUser.table}_${TableUserGroup.table} ON ${TableUserUserGroup.table} (
	${TableUserUserGroup.idUser.column}	ASC,
	${TableUserUserGroup.idUserGroup.column} ASC)''',

    '''CREATE UNIQUE INDEX IF NOT EXISTS index_${TableTask.table}_${TableTaskGroup.table} ON ${TableTaskTaskGroup.table} (
	${TableTaskTaskGroup.idTaskGroup.column} ASC,
	${TableTaskTaskGroup.idTask.column}	ASC)''',
  ];

  static final List<String> inserts = [
    'INSERT INTO ${TableLocationGroup.table} (title) VALUES ("Default Locationgroup")',
    'INSERT INTO ${TableUserGroup.table} (title) VALUES ("Default Usergroup")',
    'INSERT INTO ${TableTaskGroup.table} (title) VALUES ("Default Taskgroup")',
  ];
}
