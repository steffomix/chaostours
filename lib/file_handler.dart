import 'dart:io' as io;
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/enum.dart';

class FileHandler {
  static Map<DatabaseFile, io.File?> handles = {
    DatabaseFile.alias: null,
    DatabaseFile.task: null,
    DatabaseFile.station: null
  };
  static Future<io.File> get alias => file(DatabaseFile.alias);
  static Future<io.File> get task => file(DatabaseFile.task);
  static Future<io.File> get station => file(DatabaseFile.station);

  static Future<io.File> file(DatabaseFile filehandle) async {
    if (handles[filehandle] != null) {
      return Future<io.File>.value(handles[filehandle]);
    }
    handles[filehandle] =
        await RecourceLoader.fileHandle('${filehandle.name}.tsv');
    return Future<io.File>.value(handles[filehandle]);
  }
}
