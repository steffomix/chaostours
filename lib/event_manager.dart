import 'package:flutter/material.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/shared.dart';

class EventOnSharedKeyChanged extends EventOn {
  SharedKeys key;
  String oldData;
  String newData;

  EventOnSharedKeyChanged(
      {required this.key, required this.oldData, required this.newData});
}

class EventOnMainPaneChanged extends EventOn {
  final Widget pane;
  EventOnMainPaneChanged(this.pane);
}

class EventOnTrackingStatusChanged extends EventOn {
  final ModelTrackPoint tp;
  EventOnTrackingStatusChanged(this.tp);
}

/// <p><b>Deprecated!</b></p>
/// moved to background tracking<br>
/// EventOnTracking
class EventOnTrackPoint extends EventOn {
  ModelTrackPoint tp;
  EventOnTrackPoint(this.tp);
}

class EventOnGPS extends EventOn {
  final GPS gps;
  EventOnGPS(this.gps);
}

class EventOnAddressLookup extends EventOn {}

class EventOnAppTick extends EventOn {
  final int id;
  EventOnAppTick(this.id);
}

class EventOn {
  /// EventManager will print this
  String msg = '';
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
      logger.log('add Listener ${T.toString()}');
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
    var list = _get<T>();
    for (var fn in list) {
      /*
      if (Globals.debugMode) {
        Logger.print(
            '$prefix $m:$s.$ms EventManager.fire<${T.toString()}>() ${list.length} times $debugMessage');
      }
      */
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
      logger.log('remove Listener ${T.toString()}');
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
