import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';

enum SharedKeys {
  /// gps
  backgroundGps,

  /// current running trackpoint
  activeTrackpoint,

  runningTrackpoints,

  /// last saved trackpoints
  recentTrackpoints,

  /// workmanager logs
  backLog;
}

enum SharedTypes {
  string,
  list;
}

class Shared {
  static Logger logger = Logger.logger<Shared>();
  String _observed = '';
  bool _observing = false;
  int _id = 0;
  int get id => ++_id;
  //
  SharedKeys key;
  Shared(this.key);

  String _typeName(SharedTypes type) {
    return '${key.name}_${type.name}';
  }

  /// prepare module
  static SharedPreferences? _shared;
  static Future<SharedPreferences> get shared async =>
      _shared ??= await SharedPreferences.getInstance();

  ///
  Future<void> add(String value) async {
    String l = await load();
    //logger.verbose('add to ${key.name}');
    l += value;
    await save(l);
  }

  Future<List<String>> loadList() async {
    SharedPreferences sh = await shared;
    await sh.reload();
    List<String> value =
        sh.getStringList(_typeName(SharedTypes.list)) ?? <String>[];
    return value;
  }

  Future<void> saveList(List<String> list) async {
    await (await shared).setStringList(_typeName(SharedTypes.list), list);
  }

  Future<String> load() async {
    SharedPreferences sh = await shared;
    await sh.reload();
    String value = sh.getString(_typeName(SharedTypes.string)) ?? '0\t';
    return value;
  }

  Future<void> save(String data) async {
    await (await shared).setString(_typeName(SharedTypes.string), data);
  }

  /// observes only string types
  void observe(
      {required Duration duration, required Function(String data) fn}) async {
    if (_observing) return;
    _observed = await load();
    Future.delayed(duration, () {
      _observe(duration: duration, fn: fn);
    });
    _observing = true;
  }

  Future<void> _observe(
      {required Duration duration, required Function(String data) fn}) async {
    String obs;
    while (true) {
      if (!_observing) break;
      try {
        obs = await load();
      } catch (e, stk) {
        logger.error('observing failed with $e', stk);
        obs = '';
      }
      if (obs != _observed) {
        _observed = obs;
        try {
          fn(obs);
        } catch (e, stk) {
          logger.error('observing failed with $e', stk);
        }
      }
      await Future.delayed(duration);
    }
  }

  void cancel() {
    logger.log('cancel observing on key ${key.name}');
    _observing = false;
  }
}
