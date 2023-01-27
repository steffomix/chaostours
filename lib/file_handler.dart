import 'package:chaostours/logger.dart';

////
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull; //util.base64Codec().encode;

class FileHandler {
  static Logger logger = Logger.logger<FileHandler>();
  static const lineSep = '\n';
  static Directory? _appDir;
  static Future<Directory> get appDir async {
    return _appDir ??= await getApplicationDocumentsDirectory();
  }

  static Future<File> getFile(String filename) async {
    String f = '${filename.toLowerCase()}.tsv';
    f = join((await appDir).path, f);
    logger.log('request access to File $f');
    File file = File(f);
    if (!file.existsSync()) {
      logger.important('file does not exist, create file $f');
      file = await file.create(recursive: true);
    }
    return file;
  }

  static Future<int> write(String filename, String content) async {
    File file = await getFile(filename);
    await file.writeAsString(content);
    return file.lengthSync();
  }

  static Future<String> read(String filename) async {
    return (await getFile(filename)).readAsString();
  }

  static Future<int> writeTable<T>(List<String> table) async {
    File file = await getFile(T.toString());
    await file.writeAsString(table.join(lineSep));
    return file.lengthSync();
  }

  static Future<List<String>> readTable<T>() async {
    File file = await getFile(T.toString());
    String data = await file.readAsString();
    if (data.trim().isEmpty) {
      return <String>[];
    }
    List<String> lines = data.split(lineSep);
    return lines;
  }
}
