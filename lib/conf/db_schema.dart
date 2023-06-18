enum TableTrackPoint {
  id('id'),
  latitude('latitude'),
  longitude('longitude'),
  timeStart('datetime_start'),
  timeEnd('datetime_end'),
  address('address');

  static const String table = 'trackpoint';

  TableTrackPoint get primaryKey {
    return id;
  }

  final String column;
  const TableTrackPoint(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${latitude.column}"	NUMERIC NOT NULL,
	"${longitude.column}"	NUMERIC NOT NULL,
	"${timeStart.column}"	TEXT NOT NULL,
	"${timeEnd.column}"	TEXT NOT NULL,
	"${address.column}"	TEXT,
	PRIMARY KEY("${id.column}" AUTOINCREMENT)
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

  TableTask get primaryKey {
    return id;
  }

  final String column;
  const TableTask(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${idTaskGroup.column}"	INTEGER NOT NULL DEFAULT 1,
	"${isActive.column}"	INTEGER DEFAULT 1,
	"${sortOrder.column}"	INTEGER DEFAULT 1,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
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
  visibility('visibilty'),
  latitude('latitude'),
  longitude('longitude'),
  title('title'),
  description('description');

  static const String table = 'alias';

  TableAlias get primaryKey {
    return id;
  }

  final String column;
  const TableAlias(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${idAliasGroup.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${visibility.column}"	INTEGER,
	"${latitude.column}"	NUMERIC NOT NULL,
	"${longitude.column}"	NUMERIC NOT NULL,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${id.column}" AUTOINCREMENT)
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

  TableUser get primaryKey {
    return id;
  }

  final String column;
  const TableUser(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${idUserGroup.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${phone.column}"	TEXT,
	"${address.column}"	TEXT,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${id.column}" AUTOINCREMENT)
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

  TableTaskGroup get primaryKey {
    return id;
  }

  final String column;
  const TableTaskGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${id.column}" AUTOINCREMENT)
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

  TableUserGroup get primaryKey {
    return id;
  }

  final String column;
  const TableUserGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${id.column}" AUTOINCREMENT)
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

  TableTopic get primaryKey {
    return id;
  }

  final String column;
  const TableTopic(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${sortOrder.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${id.column}" AUTOINCREMENT)
);''';

  @override
  String toString() {
    return '$table.$column';
  }
}

enum TableAliasGroup {
  id('id'),
  isActive('active'),
  visibility('sort'),
  title('title'),
  description('description');

  static const String table = 'alias_group';

  TableAliasGroup get primaryKey {
    return id;
  }

  final String column;
  const TableAliasGroup(this.column);

  static String get schema => '''CREATE TABLE IF NOT EXISTS "$table" (
	"${id.column}"	INTEGER NOT NULL,
	"${isActive.column}"	INTEGER,
	"${visibility.column}"	INTEGER,
	"${title.column}"	TEXT NOT NULL,
	"${description.column}"	TEXT,
	PRIMARY KEY("${id.column}" AUTOINCREMENT)
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
