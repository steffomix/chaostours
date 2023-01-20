import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
//
import 'package:chaostours/enum.dart';
import 'package:chaostours/logger.dart';

class FileHandler {
  static Logger logger = Logger.logger<FileHandler>();
  static Map<DatabaseFile, io.File?> handles = {
    DatabaseFile.alias: null,
    DatabaseFile.task: null,
    DatabaseFile.station: null
  };
  static Future<io.File> get alias async => await file(DatabaseFile.alias);
  static Future<io.File> get task async => await file(DatabaseFile.task);
  static Future<io.File> get station async => await file(DatabaseFile.station);

  static Future<io.File> file(DatabaseFile filehandle) async {
    logger.log('Provide File: ${filehandle.name}.tsv');

    //return handles[filehandle] ??= await fileHandle('${filehandle.name}.tsv');
    String filename = '${filehandle.name}.tsv';
    io.Directory appDir =
        await path_provider.getApplicationDocumentsDirectory();
    String p = path.join(appDir.path, /*'chaostours',*/ filename);
    io.File file = await io.File(p).create(recursive: true);
    logger.log('file handle created for file: $p');
    return file;
  }
/*
  static Future<io.File> fileHandle(String filename) async {
    io.Directory appDir =
        await path_provider.getApplicationDocumentsDirectory();
    String p = path.join(appDir.path, /*'chaostours',*/ filename);
    logger.log('file handle created for file: $p');
    io.File file = await io.File(p).create(recursive: true);
    return file;
  }
  */
}
