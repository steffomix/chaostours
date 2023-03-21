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

enum Storages {
  /// app installation directory
  /// unreachable
  appInternal,

  /// app data directory of internal storage
  /// .android/data/com.stefanbrinkmann.chaostours/files/chaostours/1.0
  /// on new devices only reachable with Computer and Datacable
  appLocalStorageData,

  /// app data directory of internal storage
  /// localStorage/Documents
  /// on new devices only reachable with Computer and Datacable
  appLocalStorageDocuments,

  /// Documents on sdCard
  /// <sdCard>/Documents/chaostours/1.0
  appSdCardDocuments;
}

class FileHandler {
  /// storage
  static Storages storageKey = Storages.appInternal;
  static String? storagePath;

  static String sharedFile = 'chaos.json';

  static Logger logger = Logger.logger<FileHandler>();
  static const lineSep = '\n';
  static Future<Directory> get appDir async {
    Directory dir = Directory(FileHandler.storagePath ??
        (await pp.getApplicationDocumentsDirectory()).path);
    for (var f in dir.listSync()) {
      print(f.uri);
    }
    return dir;
  }

  static Future<File> getFile(String filename) async {
    String f = '${filename.toLowerCase()}.tsv';
    f = join((await appDir).path, f);
    logger.log('request access to File $f');
    File file = File(f);
    try {
      var s = await file.readAsString();
    } catch (e, stk) {
      file = await file.create();
    }
    if (!(await file.exists())) {
      logger.important('file does not exist, create file $f');
      file = await file.create(recursive: true);
    }
    return file;
  }

  /// A File deleted from user keeps existing as a ghost.
  /// Even empty bin or phone restart doesn't help.
  /// These ghostfiles refuse to get checked properly
  /// with the File::exists() method
  Future<void> fileCreateBug(String path) async {
    File file = File(path);
    if (!(await file.exists())) {
      file = await file.create(recursive: true);
    }
  }

  /// However, a simple attempt to read this file
  /// what most likely fails, updates the file cache
  /// and the file can get recreated
  Future<void> fileCreateBugWorkaround(String path) async {
    File file = File(path);
    try {
      await file.readAsString();
    } catch (e) {
      file = await file.create();
    }
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

  static const combinePath = join;

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
  ///
  Future<String?> getStorage() async {
    Map<Storages, String?> storages = await _getAllStorages();
    String keyName = await Shared(SharedKeys.storageKey).loadString() ?? '';
    try {
      Storages key = Storages.values.byName(keyName);
      String? path = storages[key];
      if (path == null) {
        path ??= await _getAutoPath();
      }
      storageKey = key;
      storagePath = path;
      logger.important('!!! Set Storage Path to $path');
      return path;
    } catch (e) {
      logger.warn('invalid storages key "$keyName", use autopath');
      return await _getAutoPath();
    }
  }

  /// stores the path to the storage if storage is writeable
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
    FileHandler.storageKey = key;
    FileHandler.storagePath = path;
    Shared(SharedKeys.storageKey).saveString(key.name);
    Shared(SharedKeys.storagePath).saveString(path);
  }

  Future<void> _createBaseDir(String path, Storages target) async {
    Directory dir = Directory(path);
    if (!await dir.exists()) {
      // thows exception

      dir = await dir.create(recursive: true);
      File file = File(join(dir.path, 'readme.txt'));
      file.writeAsString('App Database Info');
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
