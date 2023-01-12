import 'package:chaostours/logger.dart';

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
  static Logger logger = Logger.logger<EventManager>();
  static final List<Set<dynamic>> _list = [];

  static bool listen<T>(Function(T) fn) {
    logger.log('Add Listener ${T.runtimeType}');
    return _get<T>().add(fn);
  }

  static void fire<T>(T instance) {
    logger.log('Fire Event ${T.runtimeType}');
    for (var fn in _get<T>()) {
      try {
        fn(instance);
      } catch (e) {
        logger.logWarn(e.toString());
      }
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
