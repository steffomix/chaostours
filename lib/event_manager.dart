import 'package:logger/logger.dart';

/*
enum EventKeys {
  onGps,
  onTrackPoint,
  onStatusChanged,
  onMainPaneChanged,
  ;
}
*/
class EventManager {
  static final List<Set<dynamic>> _list = [];

  static bool listen<T>(Function(T) fn) => _get<T>().add(fn);

  static void fire<T>(T instance) {
    for (var fn in _get<T>()) {
      fn(instance);
    }
  }

  static void cancel<T>(Function(T) fn) =>
      _get<T>().removeWhere((element) => element == fn);

  static Set<Function(T)> _get<T>() {
    try {
      _list.whereType<Set<Function(T)>>().first;
    } catch (e) {
      Set<Function(T)> s = {};
      _list.add(s);
    }
    return _list.whereType<Set<Function(T)>>().first;
  }
}
