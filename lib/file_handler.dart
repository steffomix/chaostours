import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:external_path/external_path.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/app_settings.dart';
import 'package:chaostours/app_hive.dart';

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
  static Storages? storageKey = Storages.notSet;
  static String? storagePath;
  static String subDirectory = join('chaostours', 'version_1.0');
  static Map<Storages, Directory?> potentialStorages = {};

  static String backgroundCacheFile = 'background_cache.json';
  static String foregroundCacheFile = 'foreground_cache.json';

  static Future<void> loadSettings() async {
    await AppHive.accessBox(
        boxName: AppHiveNames.fileHandler,
        access: (AppHive box) async {
          try {
            storagePath = box.read(
                hiveKey: AppHiveKeys.fileHandlerStoragePath, value: null);
            storageKey = Storages.values.byName(box.read<String>(
                hiveKey: AppHiveKeys.fileHandlerStorageKey,
                value: Storages.appInternal.name));
          } catch (e, stk) {
            logger.error('loadSettings $e', stk);
          }
        });
/*
    Map<Storages, String> storages = await getPotentialStorages();
    storagePath = combinePath(storages[Storages.appSdCardDocuments]!,
        ExternalPath.DIRECTORY_DOCUMENTS);
        */
  }

  static Future<void> saveSettings() async {
    if (storagePath != null) {
      await AppHive.accessBox(
          boxName: AppHiveNames.fileHandler,
          access: (AppHive box) async {
            box.write<String>(
                hiveKey: AppHiveKeys.fileHandlerStoragePath,
                value: storagePath);
            box.write<String>(
                hiveKey: AppHiveKeys.fileHandlerStorageKey,
                value: storageKey?.name ?? Storages.appInternal.name);
          });
    }
  }

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
    String keyName = AppSettings.settings[AppSettings.storageKey] ?? '';
    try {
      storageKey = Storages.values.byName(keyName);
      storagePath =
          (AppSettings.settings[AppSettings.storagePath] ?? '').isNotEmpty
              ? AppSettings.settings[AppSettings.storagePath]
              : await _getAutoPath();
      logger.important('!!! Set Storage Path to $storagePath');
      return storagePath;
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
    for (var key in storageLookupOrder.reversed) {
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
