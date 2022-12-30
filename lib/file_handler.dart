import 'package:chaostours/enum.dart';
import 'dart:io' as io;
import 'package:chaostours/recource_loader.dart';

class FileHandler {
  static const String lineSeperator = '\n';
  static Map<DatabaseFile, io.File?> handles = {
    DatabaseFile.alias: null,
    DatabaseFile.tmpalias: null,
    DatabaseFile.task: null,
    DatabaseFile.tmptask: null,
    DatabaseFile.station: null,
    DatabaseFile.tmpstation: null
  };
  static Future<io.File> get alias => _handle(DatabaseFile.alias);
  static Future<io.File> get alias_current => _handle(DatabaseFile.tmpalias);
  static Future<io.File> get task => _handle(DatabaseFile.task);
  static Future<io.File> get task_current => _handle(DatabaseFile.tmptask);
  static Future<io.File> get station => _handle(DatabaseFile.station);
  static Future<io.File> get station_current =>
      _handle(DatabaseFile.tmpstation);

  static Future<io.File> _handle(DatabaseFile filehandle) async {
    if (handles[filehandle] != null) {
      return Future<io.File>.value(handles[filehandle]);
    }
    handles[filehandle] =
        await RecourceLoader.fileHandle('${filehandle.name}.tsv');
    return Future<io.File>.value(handles[filehandle]);
  }

  static Future<List<String>> readLines(DatabaseFile h) async {
    io.File handle = await _handle(h);
    String string = await handle.readAsString();
    List<String> lines =
        string.trim().split(lineSeperator).where((e) => e.isNotEmpty).toList();
    return lines;
  }
}
