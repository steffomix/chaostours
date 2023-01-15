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

  static Future<void> fire<T>(T instance, [dispatchAsync = false]) async {
    DateTime t = DateTime.now();
    int m = t.minute;
    int s = t.second;
    int ms = t.millisecond;

    var list = _get<T>();
    print(
        '## $m:$s.$ms EventManager.fire<${T.toString()}>() _register.length: ${list.length}');
    for (var fn in list) {
      try {
        if (dispatchAsync) {
          Future.delayed(const Duration(microseconds: 10), () => fn(instance));
        } else {
          fn(instance);
        }
      } catch (e) {
        // log async
        print('## EventManager failed on ${T.toString()}');
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
    var f = _register.whereType<Set<Function(T)>>().first;
    return f;
  }
}
