import 'package:flutter/material.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/cache.dart';

class EventOnSharedKeyChanged extends EventOn {
  CacheKeys key;
  String oldData;
  String newData;

  EventOnSharedKeyChanged(
      {required this.key, required this.oldData, required this.newData});
}

class EventOnMainPaneChanged extends EventOn {
  final Widget pane;
  EventOnMainPaneChanged(this.pane);
}

class EventOnTrackingStatusChanged extends EventOn {}

/// <p><b>Deprecated!</b></p>
/// moved to background tracking<br>
/// EventOnTracking
class EventOnTrackPoint extends EventOn {
  ModelTrackPoint tp;
  EventOnTrackPoint(this.tp);
}

class EventOnCacheLoaded extends EventOn {}

class EventOnGPS extends EventOn {
  final GPS gps;
  EventOnGPS(this.gps);
}

class EventOnAppTick extends EventOn {
  static int _nextId = 0;
  final int id = (_nextId++);
  EventOnAppTick();
}

class EventOn {
  static int _nextId = 0;
  int eventId = (_nextId++);
  DateTime t = DateTime.now();
}

class EventManagerException implements Exception {
  /// A message describing the format error.
  final String message;

  /// Creates a new FormatException with an optional error [message].
  const EventManagerException([this.message = ""]);

  @override
  String toString() => "EventManagerException: $message";
}

class EventManager {
  static Logger logger = Logger.logger<EventManager>();
  static final List<Set<dynamic>> _register = [];

  static bool listen<T>(Function(T) fn) {
    bool added = _get<T>().add(fn);
    if (added) {
      //logger.verbose('add Listener ${T.toString()}');
    } else {
      logger
          .warn('add Listener  ${T.toString()} skipped: Listener already set');
    }
    return added;
  }

  /// fires event and returns result of each executed listener
  static Future<Map<dynamic Function(T), dynamic>> fire<T>(T instance,
      [dispatchAsync = true, String debugMessage = '']) async {
    DateTime t = DateTime.now();
    int m = t.minute;
    int s = t.second;
    int ms = t.millisecond;

    String prefix = Logger.prefix;
    Map<dynamic Function(T), dynamic> results = {};

    /// copy list to prevent modification during iteration
    var list = [..._get<T>()];
    for (var fn in list) {
      try {
        if (dispatchAsync) {
          results[fn] = await Future.microtask(() => fn(instance));
        } else {
          results[fn] = fn(instance);
        }
      } catch (e) {
        results[fn] = EventManagerException(e.toString());
        Logger.print(
            '$prefix $m:$s.$ms EventManager failed on ${T.toString()}: $debugMessage: ${e.toString()}');
      }
    }
    return results;
  }

  static void remove<T>(Function(T) fn) {
    var set = _get<T>();
    if (set.contains(fn)) {
      _get<T>().removeWhere((el) => el == fn);
      //logger.verbose('remove Listener ${T.toString()}');
    } else {
      logger.warn(
          'remove Listener ${T.toString()} skipped: Listener not present');
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
