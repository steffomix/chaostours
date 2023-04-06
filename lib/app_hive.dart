import 'package:hive_flutter/hive_flutter.dart';

enum AppHiveNames {
  forground,
  background,
  storage,
  appsettings;
}

enum AppHiveKeys {
  id(int);

  final Type type;
  const AppHiveKeys(this.type);
}

class AppHive {
  static const List<Type> hiveTypes = [
    int,
    double,
    bool,
    String,
    List<int>,
    List<String>,
    Map<String, String>,
    Map<String, int>,
    Map<String, double>,
    Map<int, String>,
    Map<double, String>
  ];
  final Box _box;
  AppHive._handler(this._box);

  static Future<void> accessBox(
      {required AppHiveNames boxName,
      required Future<void> Function(AppHive box) access}) async {
    Box box = await _openBox(boxName);
    await access(AppHive._handler(box));
    box.close();
  }

  read<T>({required AppHiveKeys hiveKey, required T defaultValue}) {
    var v = _box.get(hiveKey.name);
    T value = castRead<T>(v, defaultValue);
    return value;
  }

  write<T>(
      {required AppHiveKeys hiveKey, required dynamic value, Type? castAs}) {
    dynamic v = castWrite(value, castAs);
    _box.put(hiveKey.name, v);
  }

  static Future<void> init(String prefix) async {
    await Hive.initFlutter();
  }

  static T castRead<T>(dynamic value, T def) {
    Type t = value.runtimeType;
    if (t == T) {
      return value as T;
    } else if (t == String) {
      switch (T) {
        case int:
          return int.parse(value) as T;
        case double:
          return double.parse(value) as T;
        case bool:
          return (value == '1' ? true : false) as T;
        case String:
          return value.toString() as T;
        case List<int>:
          return value.split(',').map((e) => int.parse(e)).toList() as T;
        case DateTime:
          return DateTime.parse(value) as T;
        default:
          throw "Type T: $T not implemented";
      }
    } else {
      return def;
    }
  }

  static dynamic castWrite(dynamic value, [Type? tf]) {
    Type tv = value.runtimeType;
    if (hiveTypes.contains(tv)) {
      return value;
    }
    Type t = tf ?? tv;
    if (tv == tf) {
      return value;
    }
    switch (t) {
      case DateTime:
        return (value as DateTime).toIso8601String();
      default:
        throw "Type T: $t not implemented";
    }
  }

  static Future<T> readKeyFromName<T>(
      {required AppHiveNames hiveName,
      required AppHiveKeys hiveKey,
      required T defaultValue}) async {
    Box box = await _openBox(hiveName);
    var v = box.get(AppHiveKeys.id.name);
    T value = castRead<T>(v, defaultValue);
    box.close();
    return value;
  }

  static Future<void> writeKeyToName<T>(
      {required AppHiveNames hiveName,
      required AppHiveKeys hiveKey,
      required dynamic value,
      Type? castAs}) async {
    dynamic v = castWrite(value, castAs);
    Box box = await _openBox(hiveName);
    box.put(hiveKey, v);
    box.close();
  }

  static void log(Object msg) {
    String t = DateTime.now().millisecond.toString();
    // ignore: avoid_print
    print('$t::$msg');
  }

  static Future<Box> _openBox(AppHiveNames boxName) async {
    String n = boxName.toString();
    try {
      if (Hive.isBoxOpen(n)) {
        return Hive.box(n);
      }
      if (await Hive.boxExists(n) && !Hive.isBoxOpen(n)) {
        await Hive.openBox(n);
        return Hive.box(n);
      }
    } catch (e) {
      log(e);
    }

    Box b;

    try {
      b = Hive.box(n);
    } catch (e) {
      log(e);
      while (true) {
        try {
          b = await Hive.openBox(n);
          log('box opened');
          break;
        } catch (e) {
          log(e);
          // take a breath and try again
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }
    return b;
  }
}
