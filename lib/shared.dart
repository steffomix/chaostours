import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/log.dart';

enum SharedKeys {
  backgroundGps,
  tracker;
}

class Shared {
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
      return _decode(s);
    }
    return null;
  }

  Future<void> add(String value) async {
    String l = await load() ?? '';
    l += value;
    await save(l);
  }

  Future<String?> _loadRaw() async {
    final sh = await shared;
    await sh.reload();
    return sh.getString(key.name);
  }

  Future<void> save(String data) async {
    await (await shared).setString(key.name, _encode(data));
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
      print('### observed new gps: $obs');
      _observed = obs;
      try {
        fn(_decode(obs));
      } catch (e) {
        logError(e);
      }
    }
    Future.delayed(duration, () {
      _observe(duration: duration, fn: fn);
    });
  }

  void cancel() {
    _observing = false;
  }
}
