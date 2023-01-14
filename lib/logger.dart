import 'package:flutter/material.dart';
//
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';

enum LogLevel {
  verbose(1),
  log(2),
  important(3),
  warn(4),
  error(5),
  fatal(6),
  off(7);

  final int level;
  const LogLevel(this.level);
}

class Logger {
  static List<Widget> widgetLogs = [];
  static int maxWidgetCount = 200;
  static Function(
          String loggerName, LogLevel level, String msg, StackTrace? stackTrace)
      printer = logPrinter;
  static Function(LogLevel level, String msg, [StackTrace? stackTrace])
      logRenderer = renderLog;
  static LogLevel logLevel = LogLevel.log;
  static final Map<String, Logger> _logger = {};
  static List<String> get names => _logger.keys.toList();
  static Logger? getLoggerByName(String name) => _logger[name];
  static String prefix = '#';
  bool enabled = true;
  String _name = 'Logger'; // runtimeType
  String get name => _name;

  static String get time {
    DateTime t = DateTime.now();
    var s = t.second;
    var ms = t.millisecond;
    return '$s:$ms';
  }

  static String get _prefix {
    return '$prefix $time ::';
  }

  //
  static Logger logger<T>() {
    Logger l = Logger();
    String n = T.toString();
    l.log('Logger for class $n created');
    l._name = n;
    _logger[n] = l;
    return l;
  }

  void verbose(String msg, [fireEvent = true]) =>
      _log(LogLevel.verbose, msg, null);
  void log(String msg, [fireEvent = true]) => _log(LogLevel.log, msg, null);
  void important(String msg, [fireEvent = true]) =>
      _log(LogLevel.important, msg, null);
  void warn(String msg, [fireEvent = true]) => _log(LogLevel.warn, msg, null);
  void error(String msg, StackTrace? stackTrace, [fireEvent = true]) =>
      _log(LogLevel.verbose, msg, stackTrace);
  void fatal(String msg, StackTrace? stackTrace, [fireEvent = true]) =>
      _log(LogLevel.fatal, msg, stackTrace);

  static void logPrinter(
      String loggerName, LogLevel level, String msg, StackTrace? stackTrace) {
    String stk = '';
    if (stackTrace != null) {
      stk = '\n$stackTrace';
    }
    msg = '$_prefix${level.name} $time<$loggerName>:: $msg$stk';

    try {
      // ignore: avoid_print
      print(msg);
    } catch (e) {
      // ignore
    }
  }

  void _log(LogLevel level, String msg, StackTrace? stackTrace,
      [fireEvent = true]) {
    if (level.level >= logLevel.level && enabled) {
      // prevent stack overflow due to EventManager.fire triggers a log
      if (fireEvent) {
        EventManager.fire<EventOnLog>(EventOnLog(level, msg));
      }
      logPrinter(_name, level, msg, stackTrace);
      _addLogWidget(logRenderer(level, msg, stackTrace));
    }
  }

  static void _addLogWidget(Widget log) {
    while (widgetLogs.length > maxWidgetCount) {
      widgetLogs.removeAt(0);
    }
    widgetLogs.add(log);
  }

  static Widget renderLog(LogLevel level, String msg,
      [StackTrace? stackTrace]) {
    switch (level) {
      case LogLevel.verbose:
        return Container(
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black45)));

      case LogLevel.log:
        return Container(
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case LogLevel.important:
        return Container(
            color: Colors.greenAccent,
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)));

      case LogLevel.warn:
        return Container(
            color: Colors.yellow,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case LogLevel.error:
        return Container(
            color: Colors.red,
            child: Text('$msg\n$stackTrace',
                style: const TextStyle(color: Colors.white)));

      default: // LogLevel.fatal:
        return Container(
            color: Colors.purple,
            child: Text('$msg\n$stackTrace',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)));
    }
  }
}
