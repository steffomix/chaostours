import 'package:chaostours/util.dart' as util;
import 'dart:io' as io;
import 'package:file/file.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/file_handler.dart';

var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull; //util.base64Codec().encode;

class Model {
  static const lineSep = '\n';
  static const rowEnd = '|';

  static Future<io.File> writeTable(
      {required io.File handle, required List<dynamic> table}) async {
    List<String> lines = [];
    for (var m in table) {
      lines.add(m.toString());
    }
    String out = lines.join('$rowEnd$lineSep'); // line end + newline
    out += rowEnd; // don't foret the line end on last line :s
    io.File file =
        await handle.writeAsString(out, mode: FileMode.write, flush: true);
    return Future<io.File>.value(file);
  }

  static Future<List<String>> readTable(DatabaseFile file) async {
    io.File handle = await FileHandler.file(file);
    String string = await handle.readAsString();
    string = string.trim();
    if (string.isEmpty) return <String>[];
    List<String> lines = string.split('$rowEnd$lineSep');
    return lines;
  }

  static Set<int> parseIdList(String string) {
    string = string;
    Set<int> ids = {};
    if (string.isEmpty) return ids;
    List<String> list = string.split(',').where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return ids;
    for (var item in list) {
      ids.add(int.parse(item));
    }
    return ids;
  }
}
