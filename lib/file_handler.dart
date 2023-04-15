import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:external_path/external_path.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';

////

var decode = Uri.decodeFull; // util.base64Codec().decode;
var encode = Uri.encodeFull; //util.base64Codec().encode;

enum Storages {
  /// storage is not yet set by user
  notSet,

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
  static Storages? storageKey;
  static String? storagePath;
  static String subDirectory = join('chaostours', 'version_1.0');
  static String? get storageFullPath {
    if (storagePath == null) {
      return null;
    }
    return join(storagePath!, subDirectory);
  }

  static Future<void> saveSettings() async {
    await Cache.setValue<Storages>(
        CacheKeys.fileHandlerStorageKey, storageKey ?? Storages.notSet);
    storagePath == null
        ? await Cache.setValue(CacheKeys.fileHandlerStoragePathDelete, null)
        : await Cache.setValue<String>(
            CacheKeys.fileHandlerStoragePath, storagePath!);
  }

  static Future<void> loadSettings() async {
    storageKey = await Cache.getValue<Storages>(
        CacheKeys.fileHandlerStorageKey, Storages.notSet);
    String path =
        await Cache.getValue<String>(CacheKeys.fileHandlerStoragePath, '');
    storagePath = path == '' ? null : path;
  }

  static Map<Storages, Directory?> potentialStorages = {};

  static Logger logger = Logger.logger<FileHandler>();
  static const lineSep = '\n';
  static Future<Directory> get appDir async {
    Directory dir = Directory(FileHandler.storagePath ??
        (await pp.getApplicationDocumentsDirectory()).path);
    return dir;
  }

  static Future<File> getFile(String filename) async {
    String f = filename.contains('.')
        ? filename.toLowerCase()
        : '${filename.toLowerCase()}.tsv';
    f = join((await appDir).path, f);
    //logger.log('request access to File $f');
    File file = File(f);
    try {
      await file.readAsString();
    } catch (e) {
      file = await file.create();
    }
    if (!(await file.exists())) {
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

  static const combinePath = join;

  static Future<Map<Storages, Directory?>> getPotentialStorages() async {
    List<String> extPathes = await ExternalPath.getExternalStorageDirectories();
    potentialStorages.clear();
    //
    potentialStorages[Storages.appInternal] =
        await pp.getApplicationDocumentsDirectory();
    //
    potentialStorages[Storages.appLocalStorageData] =
        await pp.getExternalStorageDirectory();

    if (extPathes.isNotEmpty) {
      String path = join(extPathes[0], ExternalPath.DIRECTORY_DOCUMENTS);
      Directory dir = Directory(path);
      if (await dir.exists()) {
        potentialStorages[Storages.appLocalStorageDocuments] = dir;
      } else {
        potentialStorages[Storages.appLocalStorageDocuments] = null;
      }
    }

    if (extPathes.length > 1) {
      String path = join(extPathes[1], ExternalPath.DIRECTORY_DOCUMENTS);
      Directory dir = Directory(path);
      if (await dir.exists()) {
        potentialStorages[Storages.appSdCardDocuments] = dir;
      } else {
        potentialStorages[Storages.appSdCardDocuments] = null;
      }
    }

    return potentialStorages;
  }

  static Future<bool> dirExists(String path) async {
    var dir = Directory(path);
    return await dir.exists();
  }
}
