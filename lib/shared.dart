import 'package:shared_preferences/shared_preferences.dart';
import 'package:chaostours/log.dart';

enum SharedKeys {
  gps;
}

class Shared {
  String _observed = '';
  bool _observing = false;
  static int _nextId = 0;
  int _id = 0;
  int get id => _id;
  //
  SharedKeys key;
  late String _data;
  Shared({required this.key, required String data}) {
    _data = data;
  }

  /// prepare module
  static SharedPreferences? _shared;
  static Future<SharedPreferences> get shared async =>
      _shared ??= await SharedPreferences.getInstance();

  ///
  Future<String?> load() async {
    String? s = await _load();
    if (s != null) {
      return _decode(s);
    }
    return null;
  }

  Future<String?> _load() async {
    final sh = await shared;
    await sh.reload();
    return sh.getString(key.name);
  }

  Future<void> save() async {
    await (await shared).setString(key.name, _encode(_data));
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
    _observed = await _load() ?? '';
    Future.delayed(duration, () {
      _observe(duration: duration, fn: fn);
    });
    _observing = true;
  }

  Future<void> _observe(
      {required Duration duration, required Function(String data) fn}) async {
    if (!_observing) return;
    String obs = await _load() ?? '';
    if (obs != _observed) {
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
