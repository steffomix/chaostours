import 'package:flutter/material.dart';
//
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';
import 'shared_model/shared.dart';

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
  static List<String> _sharedLogs = [];
  static int maxSharedCount = 200;
  static int maxWidgetCount = 200;
  //
  static Function(String, LogLevel, String, [String?]) printer = logPrinter;
  //
  static Set<void Function(String, LogLevel, String, String?)>
      additionalPrinter = {};
  //
  static Function(LogLevel, String, [String?]) logRenderer = renderLog;
  //
  static LogLevel logLevel = LogLevel.verbose;
  //
  static String prefix = '##';
  bool enabled = true;
  String _name = 'Logger'; // runtimeType
  String get name => _name;

  static bool addPrinter(Function(String, LogLevel, String, String?) p) {
    return additionalPrinter.add(p);
  }

  static bool removePrinter(Function(String, LogLevel, String, String?) p) {
    return additionalPrinter.remove(p);
  }

  static String get time {
    DateTime t = DateTime.now();
    var s = t.second;
    var ms = t.millisecond;
    return '$s:$ms';
  }

  //
  static Logger logger<T>() {
    Logger l = Logger();
    String n = T.toString();
    l.log('Logger for class $n created');
    return l;
  }

  void verbose(String msg, [fireEvent = true]) =>
      _log(LogLevel.verbose, msg, null);
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

  void _log(LogLevel level, String msg, String? stackTrace,
      [fireEvent = true]) {
    if (level.level >= logLevel.level && enabled) {
      // prevent stack overflow due to EventManager.fire triggers a log
      if (fireEvent) {
        EventManager.fire<EventOnLog>(EventOnLog(level, msg), true);
      }
      msg = logPrinter(_name, level, msg, stackTrace?.toString());
      _addLogWidget(logRenderer(level, msg, stackTrace));
      _addSharedLog(level, msg, stackTrace?.toString());
      renderBackLog();
    }
  }

  static String logPrinter(String loggerName, LogLevel level, String msg,
      [String? stackTrace]) {
    msg = composeMessage(loggerName, level, msg, stackTrace);

    try {
      // ignore: avoid_print
      print(msg);
    } catch (e) {
      // ignore
    }
    for (var p in additionalPrinter) {
      try {
        p(loggerName, level, msg, stackTrace);
      } catch (e, stk) {
        // ignore: avoid_print
        print(e.toString());
      }
    }
    return msg;
  }

  static String composeMessage(
      String loggerName, LogLevel level, String msg, String? stackTrace) {
    String stk = '';
    if (stackTrace != null) {
      stk = '\n$stackTrace';
    }
    return '$prefix $time ::${level.name} $time<$loggerName>:: $msg$stk';
  }

  static void _addLogWidget(Widget log) {
    while (widgetLogs.length > maxWidgetCount) {
      widgetLogs.removeAt(0);
    }
    widgetLogs.add(log);
  }

  static Widget renderLog(LogLevel level, String msg, [String? stackTrace]) {
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
      prefix,
      name,
      level.name,
      Uri.encodeFull(msg),
      Uri.encodeFull('$stackTrace'),
      '|'
    ];
    Shared shared = Shared(SharedKeys.backLog);
    List<String> list = await shared.loadList();
    while (list.length >= maxSharedCount) {
      list.removeLast();
    }
    _sharedLogs.insert(0, parts.join('\t'));
    await shared.saveList(list);
  }

  renderBackLog() async {
    Shared shared = Shared(SharedKeys.backLog);
    String data = await shared.load();
    await shared.save('');
    if (data.isEmpty) return;
    List<String> dataList = data.split('\n');
    String loggerName;
    LogLevel level;
    String msg;
    String stackTrace;
    List<String> p;
    List<Widget> widgets = [];
    for (var entry in dataList) {
      p = entry.split('\t');
      loggerName = p[0];
      level = LogLevel.values.byName(p[1]);
      msg = p[2];
      stackTrace = p[3];

      widgets
          .add(renderLog(level, composeMessage(loggerName, level, msg, null)));
    }
    Logger.widgetLogs.addAll(widgets);
  }
}
