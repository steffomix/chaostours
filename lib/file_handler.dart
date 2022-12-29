import 'package:chaostours/enum.dart';
import 'dart:io' as io;
import 'package:chaostours/recource_loader.dart';

class FileHandler {
  static const String lineSeperator = '\n';
  static Map<FileHandle, io.File?> handles = {
    FileHandle.alias: null,
    FileHandle.alias_current: null,
    FileHandle.task: null,
    FileHandle.task_current: null,
    FileHandle.station: null,
    FileHandle.station_current: null
  };
  static Future<io.File> get alias => _handle(FileHandle.alias);
  static Future<io.File> get alias_current => _handle(FileHandle.alias_current);
  static Future<io.File> get task => _handle(FileHandle.task);
  static Future<io.File> get task_current => _handle(FileHandle.task_current);
  static Future<io.File> get station => _handle(FileHandle.station);
  static Future<io.File> get station_current =>
      _handle(FileHandle.station_current);

  static Future<io.File> _handle(FileHandle filehandle) async {
    if (handles[filehandle] != null) {
      return Future<io.File>.value(handles[filehandle]);
    }
    handles[filehandle] =
        await RecourceLoader.fileHandle('${filehandle.name}.tsv');
    return Future<io.File>.value(handles[filehandle]);
  }

  static Future<List<String>> readLines(FileHandle h) async {
    io.File handle = await _handle(h);
    String string = await handle.readAsString();
    List<String> lines = string.split(lineSeperator);
    return lines;
  }
}
