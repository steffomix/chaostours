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
  static Future<io.File> get alias async => await file(DatabaseFile.alias);
  static Future<io.File> get task async => await file(DatabaseFile.task);
  static Future<io.File> get station async => await file(DatabaseFile.station);

  static Future<io.File> file(DatabaseFile filehandle) async {
    /*
    if (handles[filehandle] != null) {
      return Future<io.File>.value(handles[filehandle]);
    }
    handles[filehandle] =
        await RecourceLoader.fileHandle('${filehandle.name}.tsv');
    //return Future<io.File>.value(handles[filehandle]);
    */
    return handles[filehandle] ??=
        await RecourceLoader.fileHandle('${filehandle.name}.tsv');
  }
}
