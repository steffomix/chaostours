import 'package:flutter/material.dart';
//
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:chaostours/globals.dart';

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

class EventOnLog {
  final Logger logger;
  final String prefix;
  final String name;
  final LogLevel level;
  final String msg;
  final String? stackTrace;
  EventOnLog(
      {required this.logger,
      required this.prefix,
      required this.name,
      required this.level,
      required this.msg,
      required this.stackTrace});
}

class Logger {
  static bool dispatch = EventManager.listen<EventOnTick>((EventOnTick event) {
    /// render events from background thread
    /// and add them to widgetLogs
    renderBackLog();
  });
  static Future<void> onTick(EventOnTick event) async {
    /// render events from background thread
    /// and add them to widgetLogs
    await renderBackLog();
  }

  /// rendered widgetLogs to be displayed in WidgetLogger
  static List<Widget> widgets = [];

  static List<Widget> getWidgetLogs() {
    List<Widget> list = [];
    int i = 0;
    for (var w in widgets) {
      list.add(w);
    }
    return list;
  }

  /// max events from background stored in Shared
  static int maxSharedCount = 50;

  /// max events to be displayed
  static int maxWidgetCount = 200;

  /// backgroundLogger does not render widgets or render from Shared,
  /// but renders only to Shared
  static bool backgroundLogger = false;
  static LogLevel logLevel = LogLevel.verbose;

  static final Map<String, Logger> _register = {};

  /// To be different from background logger
  static String prefix = '##';
  bool enabled = true;

  /// Class name of what class created the logger.
  /// defaults to Logger
  String _name = 'Logger'; // ignore: prefer_final_fields
  String get loggerId => _name;

  static String get time {
    DateTime t = DateTime.now();
    var m = t.minute;
    var s = t.second;
    var ms = t.millisecond;
    return '$m:$s.$ms';
  }

  /// constructor
  static Logger logger<T>() {
    Logger l = Logger();
    String n = T.toString();
    l._name = n;
    _register[n] = l;
    l.log('Logger for class $n created');
    return l;
  }

  /// Usage:
  /// ```
  /// MyClass{
  ///   static Logger logger = Logger.logger<MyClass>();
  /// ```
  Logger() {
    //throw 'Usage: static Logger logger = Logger.logger<MyClass>();';
  }

  void verbose(String msg) => _log(LogLevel.verbose, msg, null);
  //
  void log(String msg, [fireEvent = true]) => _log(LogLevel.log, msg, null);
  //
  void important(String msg, [fireEvent = true]) =>
      _log(LogLevel.important, msg, null);
  //
  void warn(String msg, [fireEvent = true]) => _log(LogLevel.warn, msg, null);
  //
  void error(String msg, StackTrace? stackTrace, [fireEvent = true]) =>
      _log(LogLevel.error, msg, stackTrace.toString());
  //
  void fatal(String msg, StackTrace? stackTrace, [fireEvent = true]) =>
      _log(LogLevel.fatal, msg, stackTrace.toString());

  /// main log method
  void _log(LogLevel level, String msg, String? stackTrace) {
    if (level.level >= logLevel.level && enabled) {
      msg = composeMessage(_name, level, msg, stackTrace);
      try {
        if (!Globals.debugMode) {
          print('$prefix $msg'); // ignore: avoid_print
        }
      } catch (e) {
        // ignore
      }
      if (backgroundLogger) {
        _addSharedLog(level, msg, stackTrace);
      } else {
        while (widgets.length > maxWidgetCount) {
          widgets.removeAt(0);
        }
        _addLogWidget(renderLog(prefix, level, msg, stackTrace));
        renderBackLog();
      }
      // prevent stack overflow due to EventManager.fire triggers a log
      if (_name != 'EventManager') {
        EventManager.fire<EventOnLog>(EventOnLog(
            logger: this,
            prefix: prefix,
            name: loggerId,
            level: level,
            msg: msg,
            stackTrace: stackTrace));
      }
    }
  }

  /// compose without prefix due to background process uses a different one
  static String composeMessage(
      String loggerName, LogLevel level, String msg, String? stackTrace) {
    String stk = '';
    if (stackTrace != null) {
      stk = '\n$stackTrace';
    }
    return '$time ::${level.name} $time<$loggerName>:: $msg$stk';
  }

  static Widget renderLog(String prefix, LogLevel level, String msg,
      [String? stackTrace]) {
    msg = '$prefix $msg';
    switch (level) {
      case LogLevel.verbose:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black45)));

      case LogLevel.log:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case LogLevel.important:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.greenAccent,
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)));

      case LogLevel.warn:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.yellow,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case LogLevel.error:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.red,
            child: Text('$msg\n$stackTrace',
                style: const TextStyle(color: Colors.white)));

      default: // LogLevel.fatal:
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.purple,
            child: Text('$msg\n$stackTrace',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)));
    }
  }

  _addSharedLog(LogLevel level, String msg, String? stackTrace) async {
    List<String> parts = [
      Uri.encodeFull(prefix),
      Uri.encodeFull(_name),
      Uri.encodeFull(level.name),
      Uri.encodeFull(msg),
      Uri.encodeFull('$stackTrace'),
      '|'
    ];
    Shared shared = Shared(SharedKeys.backLog);
    List<String> list = await shared.loadList();
    while (list.length >= maxSharedCount) {
      list.removeLast();
    }
    list.add(parts.join('\t'));
    await shared.saveList(list);
    list = await shared.loadList();
  }

  static Future<void> renderBackLog() async {
    Shared shared = Shared(SharedKeys.backLog);
    List<String> list = await shared.loadList();
    await shared.saveList(<String>[]);
    for (var item in list) {
      List<String> p = item.split('\t');
      String prefix = Uri.decodeFull(p[0]);
      String loggerName = Uri.decodeFull(p[1]);
      LogLevel level = LogLevel.values.byName(Uri.decodeFull(p[2]));
      String msg = Uri.decodeFull(p[3]);
      String stackTrace = Uri.decodeFull(p[4]);
      msg = composeMessage(loggerName, level, msg, stackTrace);
      EventManager.fire<EventOnLog>(EventOnLog(
          logger: _register[loggerName] ?? Logger.logger<EventOnLog>(),
          prefix: prefix,
          name: loggerName,
          level: level,
          msg: msg,
          stackTrace: stackTrace));
      _addLogWidget(renderLog(prefix, level, msg));
    }
  }

  static _addLogWidget(Widget widget) {
    widgets.insert(0, widget);
    while (widgets.length > 200) {
      widgets.removeLast();
    }
  }
}
