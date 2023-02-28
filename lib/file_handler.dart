import 'dart:io';
import 'package:path/path.dart';
import 'package:chaostours/globals.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:external_path/external_path.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared.dart';

////

var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull; //util.base64Codec().encode;

class FileHandler {
  static Logger logger = Logger.logger<FileHandler>();
  static const lineSep = '\n';
  static Future<Directory> get appDir async {
    return Directory(Globals.storagePath ??
        (await pp.getApplicationDocumentsDirectory()).path);
  }

  static Future<File> getFile(String filename) async {
    String f = '${filename.toLowerCase()}.tsv.txt';
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
    await logger.log('write ${content.length} bytes to $filename');
    return file.lengthSync();
  }

  static Future<String> read(String filename) async {
    String content = await (await getFile(filename)).readAsString();
    await logger.log('read ${content.length} bytes from $filename');
    return content;
  }

  static Future<int> writeTable<T>(List<String> table) async {
    File file = await getFile(T.toString());
    await file.writeAsString(table.join(lineSep));
    await logger.log('write ${table.length} rows to $file');
    return file.lengthSync();
  }

  static Future<List<String>> readTable<T>() async {
    File file = await getFile(T.toString());
    String data = await file.readAsString();
    if (data.trim().isEmpty) {
      return <String>[];
    }
    List<String> lines = data.split(lineSep);
    await logger.log('read ${lines.length} rows from $file');
    return lines;
  }

  ///
  ///
  ///
  /// ################# Instance #############
  ///
  ///   Detect and set storage to Shared data and Globals
  ///
  ///
  ///

  ///
  Future<String?> getStorage() async {
    Map<Storages, String?> storages = await _getAllStorages();
    String? key = await Shared(SharedKeys.storageKey).loadString();
    if (key == null) {
      return _getAutoPath();
    } else {
      return storages[key] ?? await _getAutoPath();
    }
  }

  static final Map<Storages, String?> storages = {
    Storages.appInternal: null,
    Storages.appLocalStorageData: null,
    Storages.appLocalStorageDocuments: null,
    Storages.appSdCardDocuments: null
  };

  Future<Map<Storages, String?>> _getAllStorages() async {
    await lookupStorages();
    return storages;
  }

  Future<String?> _getAutoPath() async {
    List<Storages> storageLookupOrder = [
      Storages.appSdCardDocuments,
      Storages.appLocalStorageDocuments,
      Storages.appLocalStorageData,
      Storages.appInternal,
    ];
    Map<Storages, String?> storages = await _getAllStorages();
    for (var key in storageLookupOrder) {
      if (storages[key] != null) {
        _setStorage(key, storages[key]!);
      }
      return storages[key]!;
    }
    return null;
  }

  Future<void> _setStorage(Storages key, String path) async {
    Globals.storageKey = key;
    Globals.storagePath = path;
    Shared(SharedKeys.storageKey).saveString(key.name);
    Shared(SharedKeys.storagePath).saveString(path);
  }

  Future<void> _createBaseDir(String path, Storages target) async {
    Directory dir = Directory(path);
    if (!dir.existsSync()) {
      // thows exception
      dir = await dir.create(recursive: true);
      storages[target] = dir.path;
      logger.log(dir.path);
    } else {
      storages[target] = dir.path;
      logger.log(dir.path);
    }
  }

  Future<void> lookupStorages() async {
    logger.log('lookup pathes');

    /// internal storages
    try {
      Directory appDir = await pp.getApplicationDocumentsDirectory();
      String path = join(appDir.path, 'version_${Globals.version}');
      _createBaseDir(path, Storages.appInternal);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    /// external storage
    try {
      var appDir = await pp.getExternalStorageDirectory();
      if (appDir?.path != null) {
        String path = join(appDir!.path, 'version_${Globals.version}');
        _createBaseDir(path, Storages.appLocalStorageData);
      }
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    /// Phone Documents
    try {
      List<String> pathes = await ExternalPath.getExternalStorageDirectories();
      String path = join(pathes[0], ExternalPath.DIRECTORY_DOCUMENTS,
          'ChaosTours', 'version_${Globals.version}');
      _createBaseDir(path, Storages.appLocalStorageDocuments);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }

    /// sdCard documents
    try {
      List<String> pathes = await ExternalPath.getExternalStorageDirectories();
      String path = join(pathes[1], ExternalPath.DIRECTORY_DOCUMENTS,
          'ChaosTours', 'version_${Globals.version}');
      _createBaseDir(path, Storages.appSdCardDocuments);
    } catch (e, stk) {
      logger.error(e.toString(), stk);
    }
  }
}
