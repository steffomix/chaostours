import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';

enum SharedKeys {
  backgroundGps,
  activeTrackpoint;
}

class Shared {
  static Logger logger = Logger.logger<Shared>();
  String _observed = '';
  bool _observing = false;
  static int _nextId = 0;
  int _id = 0;
  int get id => _id;
  //
  SharedKeys key;
  Shared(this.key);

  /// prepare module
  static SharedPreferences? _shared;
  static Future<SharedPreferences> get shared async =>
      _shared ??= await SharedPreferences.getInstance();

  ///
  Future<String?> load() async {
    String? s = await _loadRaw();
    if (s != null) {
      s = _decode(s);
      logger.log('load key ${key.name}: $s');
      return s;
    }
    return null;
  }

  Future<void> add(String value) async {
    String l = await load() ?? '';
    logger.log('at ${key.name} add "$value" to "$l"');
    l += value;
    await save(l);
  }

  Future<String?> _loadRaw() async {
    final sh = await shared;
    await sh.reload();
    String? value = sh.getString(key.name);
    logger.verbose('load raw data: "$value"');
    return value;
  }

  Future<void> save(String data) async {
    String encoded = _encode(data);
    logger.log('save key ${key.name} with data "$data" to encoded "$encoded"');
    await (await shared).setString(key.name, encoded);
  }

  String _encode(String data) {
    _id = ++_nextId;
    return Uri.encodeFull('$id\t$data');
  }

  String _decode(String data) {
    data = Uri.decodeFull(data);
    List<String> parts = data.split('\t');
    return parts[1];
  }

  void observe(
      {required Duration duration, required Function(String data) fn}) async {
    logger
        .log('observe ${key.name} with ${duration.inMilliseconds}ms interval');
    _observed = await _loadRaw() ?? '';
    Future.delayed(duration, () {
      _observe(duration: duration, fn: fn);
    });
    _observing = true;
  }

  Future<void> _observe(
      {required Duration duration, required Function(String data) fn}) async {
    if (!_observing) return;
    String obs = await _loadRaw() ?? '';
    if (obs != _observed) {
      EventManager.fire<EventOnSharedKeyChanged>(
          EventOnSharedKeyChanged(key: key, oldData: _observed, newData: obs));
      logger.log('Key ${key.name} changed from $_observed to $obs');
      _observed = obs;
      try {
        fn(_decode(obs));
      } catch (e, stk) {
        logger.error('observing failed with $e', stk);
      }
    }
    Future.delayed(duration, () {
      _observe(duration: duration, fn: fn);
    });
  }

  void cancel() {
    logger.log('cancel observing on key ${key.name}');
    _observing = false;
  }
}
