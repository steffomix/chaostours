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
  static final List<Set<dynamic>> _register = [];

  static bool listen<T>(Function(T) fn) {
    bool added = _get<T>().add(fn);
    if (added) {
      logger.log('add Listener ${T.toString()}', false);
    } else {
      logger.warn(
          'add Listener  ${T.toString()} skipped: Listener already set', false);
    }
    return added;
  }

  static Future<void> fire<T>(T instance, [async = true]) async {
    for (var fn in _get<T>()) {
      try {
        async
            ? Future.delayed(
                const Duration(microseconds: 1), () => fn(instance))
            : fn(instance);
      } catch (e) {
        // log async
        Future.delayed(const Duration(milliseconds: 10), () {
          logger.warn(e.toString(), false);
        });
        ;
      }
    }
  }

  static void remove<T>(Function(T) fn) {
    var set = _get<T>();
    if (set.contains(fn)) {
      _get<T>().removeWhere((el) => el == fn);
      logger.log('remove Listener ${T.toString()}', false);
    } else {
      logger.warn(
          'remove Listener ${T.toString()} skipped: Listener not present',
          false);
    }
  }

  static Set<Function(T)> _get<T>() {
    try {
      _register.whereType<Set<Function(T)>>().first;
    } catch (e) {
      Set<Function(T)> s = {};
      _register.add(s);
    }
    return _register.whereType<Set<Function(T)>>().first;
  }
}
