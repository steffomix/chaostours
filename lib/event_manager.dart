import 'package:chaostours/logger.dart';
import 'package:chaostours/events.dart';

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
    bool added = _get<T>().add(fn);
    if (added) {
      logger.log('add Listener ${T.toString()}');
    } else {
      logger
          .warn('add Listener  ${T.toString()} skipped: Listener already set');
    }
    return added;
  }

  static void fire<T>(T instance, [async = false]) {
    //logger.log('Fire Event ${T.toString()}', false);
    for (var fn in _get<T>()) {
      try {
        async
            ? Future.delayed(
                const Duration(microseconds: 1), () => fn(instance))
            : fn(instance);
      } catch (e) {
        logger.warn(e.toString());
      }
    }
  }

  static void remove<T>(Function(T) fn) {
    var set = _get<T>();
    if (set.contains(fn)) {
      _get<T>().removeWhere((el) => el == fn);
      logger.log('remove Listener ${T.toString()}');
    } else {
      logger.warn(
          'remove Listener ${T.toString()} skipped: Listener not present');
    }
  }

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
