import 'package:chaostours/util.dart' as util;
import 'dart:io' as io;
import 'package:file/file.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/file_handler.dart';

var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull; // util.base64Codec().encode;

class Model {
  static Future<bool> writeTable(
      {required io.File handle, required List<dynamic> table}) async {
    List<String> lines = [];
    table.forEach((m) => lines.add(m.toString()));
    String out = lines.join(FileHandler.lineSeperator);
    await handle.writeAsString(out, mode: FileMode.write, flush: true);
    return true;
  }

  static Future<bool> insertRow(
      {required io.File handle, required String line}) async {
    await handle.writeAsString('\n$line', mode: FileMode.append, flush: true);
    return true;
  }

  static int parseNextId(List<String> table) {
    int id;
    try {
      id = int.parse(table.first.trim());
    } catch (e) {
      id = 1;
    }
    return id;
  }

  static int walkLines(List<String> list, Function(String item) fn) {
    int i = -1;
    String el;
    while (true) {
      try {
        el = list[++i];
      } catch (e) {
        break;
      }
      try {
        fn(el.trim());
      } catch (e) {
        logError(e);
      }
    }
    return i;
  }

  //
  static Set<GPS> parseTrackPointList(String string) {
    Set<GPS> tps = {};
    List<String> list = string.split(';');
    walkLines(list, (item) {
      List<String> coords = item.split(',');
      tps.add(GPS(double.parse(coords[0]), double.parse(coords[1])));
    });
    return tps;
  }

  static String trackPointsToString(Set<GPS> tps) {
    List<String> tpList = [];
    tps.forEach((gps) => tpList.add('${gps.lat},${gps.lon}'));
    return tpList.join(';');
  }

  static Set<int> parseIdList(String string) {
    string = string;
    Set<int> ids = {};
    if (string.isEmpty) return ids;
    List<String> list = string.split(',').where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return ids;
    walkLines(list, (String item) {
      ids.add(int.parse(item));
    });
    return ids;
  }
}
