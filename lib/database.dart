import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

///
import 'package:chaostours/logger.dart';

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
