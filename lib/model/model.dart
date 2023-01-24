import 'package:chaostours/file_handler.dart';
import 'package:chaostours/logger.dart';

////
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull; //util.base64Codec().encode;

class Model {
  static Logger logger = Logger.logger<Model>();
  static const lineSep = '\n';
  static Directory? _appDir;
  static Future<Directory> get appDir async {
    return _appDir ??= await getApplicationDocumentsDirectory();
  }

  static Future<File> getFile<T>() async {
    String f = '${T.toString().toLowerCase()}.tsv';
    f = join((await appDir).path, f);
    logger.log('request access to File $f');
    File file = File(f);
    if (!file.existsSync()) {
      logger.important('file does not exist, create file $f');
      file = await file.create(recursive: true);
    }
    return file;
  }

  static Future<int> writeTable<T>(List<String> table) async {
    File file = await getFile<T>();
    await file.writeAsString(table.join(lineSep));
    return file.lengthSync();
  }

  static Future<List<String>> readTable<T>() async {
    File file = await getFile<T>();
    String data = await file.readAsString();
    if (data.trim().isEmpty) {
      return <String>[];
    }
    List<String> lines = data.split(lineSep);
    return lines;
  }

/*
  static Future<io.File> writeTable(
      {required io.File handle, required List<dynamic> table}) async {
    String out = '';
    if (table.isNotEmpty) {
      List<String> lines = [];
      for (var m in table) {
        lines.add(m.toString());
      }
      out = lines.join(lineSep); // line end + newline
    }
    io.File file =
        await handle.writeAsString(out, mode: FileMode.write, flush: true);
    return file;
  }

  static Future<List<String>> readTable(DatabaseFile file) async {
    io.File handle = await FileHandler.file(file);
    String string = await handle.readAsString();
    string = string.trim();
    if (string.isEmpty) return <String>[];
    List<String> lines = string.split(lineSep);
    return lines;
  }
*/
  static List<int> parseIdList(String string) {
    string = string.trim();
    Set<int> ids = {}; // make sure they are unique
    if (string.isEmpty) return ids.toList();
    List<String> list = string.split(',');
    for (var item in list) {
      ids.add(int.parse(item));
    }
    return ids.toList();
  }
}
