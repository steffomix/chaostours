List<String> schema = [
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
