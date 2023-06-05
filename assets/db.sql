BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "trackpoint" (
	"id"	INTEGER NOT NULL,
	"latitude"	NUMERIC NOT NULL,
	"longitude"	NUMERIC NOT NULL,
	"datetime_start"	TEXT NOT NULL,
	"datetime_end"	TEXT NOT NULL,
	"address"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "task" (
	"id"	INTEGER NOT NULL,
	"id_task_group"	INTEGER NOT NULL DEFAULT 1,
	"title"	TEXT NOT NULL,
	"description"	TEXT NOT NULL,
	"sort"	INTEGER DEFAULT 1,
	"active"	INTEGER DEFAULT 1,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "alias" (
	"id"	INTEGER NOT NULL,
	"id_alias_group"	INTEGER NOT NULL,
	"deleted"	INTEGER NOT NULL,
	"status"	INTEGER NOT NULL,
	"latitude"	NUMERIC NOT NULL,
	"longitude"	NUMERIC NOT NULL,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE TABLE IF NOT EXISTS "user" (
	"id"	INTEGER NOT NULL,
	"id_user_group"	INTEGER NOT NULL,
	"title"	TEXT NOT NULL,
	"description"	TEXT,
	"address"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE INDEX IF NOT EXISTS "trackpoint_latitude_longitude" ON "trackpoint" (
	"latitude"	ASC,
	"longitude"	ASC
);
CREATE INDEX IF NOT EXISTS "alias_latitude_longitude" ON "alias" (
	"latitude"	ASC,
	"longitude"	ASC
);
COMMIT;
