BEGIN TRANSACTION;
DROP TABLE IF EXISTS "trackpoint";
CREATE TABLE IF NOT EXISTS "trackpoint" (
	"id"	INTEGER NOT NULL,
	"latitude"	NUMERIC NOT NULL,
	"longitude"	NUMERIC NOT NULL,
	"datetime_start"	TEXT NOT NULL,
	"datetime_end"	TEXT NOT NULL,
	"address"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
DROP TABLE IF EXISTS "trackpoint_alias";
CREATE TABLE IF NOT EXISTS "trackpoint_alias" (
	"id_trackpoint"	INTEGER NOT NULL,
	"id_alias"	INTEGER NOT NULL
);
DROP TABLE IF EXISTS "trackpoint_task";
CREATE TABLE IF NOT EXISTS "trackpoint_task" (
	"id_trackpoint"	INTEGER NOT NULL,
	"id_task"	INTEGER NOT NULL
);
DROP TABLE IF EXISTS "trackpoint_user";
CREATE TABLE IF NOT EXISTS "trackpoint_user" (
	"id_trackpoint"	INTEGER NOT NULL,
	"id_user"	INTEGER NOT NULL
);
DROP TABLE IF EXISTS "task";
CREATE TABLE IF NOT EXISTS "task" (
	"id"	INTEGER NOT NULL,
	"id_task_group"	INTEGER NOT NULL DEFAULT 1,
	"active"	INTEGER DEFAULT 1,
	"sort"	INTEGER DEFAULT 1,
	"title"	TEXT NOT NULL,
	"description"	TEXT NOT NULL,
	PRIMARY KEY("id" AUTOINCREMENT)
);
DROP TABLE IF EXISTS "alias";
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
);
DROP TABLE IF EXISTS "user";
CREATE TABLE IF NOT EXISTS "user" (
	"id"	INTEGER NOT NULL,
	"id_user_group"	INTEGER NOT NULL,
	"active"	INTEGER,
	"sort"	INTEGER,
	"address"	TEXT,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
DROP TABLE IF EXISTS "task_group";
CREATE TABLE IF NOT EXISTS "task_group" (
	"id"	INTEGER NOT NULL,
	"active"	INTEGER,
	"sort"	INTEGER,
	"title"	INTEGER,
	"description"	INTEGER,
	PRIMARY KEY("id" AUTOINCREMENT)
);
DROP TABLE IF EXISTS "user_group";
CREATE TABLE IF NOT EXISTS "user_group" (
	"id"	INTEGER NOT NULL,
	"active"	INTEGER,
	"sort"	INTEGER,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
DROP TABLE IF EXISTS "alias_topic";
CREATE TABLE IF NOT EXISTS "alias_topic" (
	"id_alias"	INTEGER,
	"id_topic"	INTEGER
);
DROP TABLE IF EXISTS "topic";
CREATE TABLE IF NOT EXISTS "topic" (
	"id"	INTEGER NOT NULL,
	"sort"	INTEGER,
	"title"	TEXT NOT NULL UNIQUE,
	"description"	INTEGER,
	PRIMARY KEY("id" AUTOINCREMENT)
);
DROP TABLE IF EXISTS "alias_group";
CREATE TABLE IF NOT EXISTS "alias_group" (
	"id"	INTEGER NOT NULL,
	"active"	INTEGER,
	"visibility"	INTEGER,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
INSERT INTO "task_group" VALUES (1,1,1,'Default Taskgroup',NULL);
INSERT INTO "user_group" VALUES (1,1,1,'Default Usergroup',NULL);
INSERT INTO "alias_group" VALUES (1,1,1,'Default Aliasgroup',NULL);
DROP INDEX IF EXISTS "trackpoint_latitude_longitude";
CREATE INDEX IF NOT EXISTS "trackpoint_latitude_longitude" ON "trackpoint" (
	"latitude"	ASC,
	"longitude"	ASC
);
DROP INDEX IF EXISTS "alias_latitude_longitude";
CREATE INDEX IF NOT EXISTS "alias_latitude_longitude" ON "alias" (
	"latitude"	ASC,
	"longitude"	ASC
);
COMMIT;
