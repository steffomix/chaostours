/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// import 'package:chaostours/event_manager.dart';
import 'package:chaostours/cache.dart';

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

class LoggerLog {
  DateTime time = DateTime.now();
  final Logger logger;
  final String prefix;
  final String name;
  final LogLevel level;
  final String msg;
  final String? stackTrace;
  LoggerLog(
      {required this.logger,
      required this.prefix,
      required this.name,
      required this.level,
      required this.msg,
      required this.stackTrace});
}

var _print = print;

class Logger {
  static final Logger _logger = Logger.logger<Logger>();

  static final Logger _exceptionLogger = Logger.logger<Logger>(
      specialBackgroundLogger: false,
      specialPrefix: '!!!LoggerException',
      specialLogLevel: LogLevel.verbose);
  static void print(Object? msg) {
    _print(msg);
  }

  static final List<LoggerLog> _loggerLogs = [];
  static List<LoggerLog> get loggerLogs {
    return [..._loggerLogs];
  }

  static void addLoggerLog(LoggerLog log) {
    while (_loggerLogs.length > 200) {
      _loggerLogs.removeLast();
    }
    _loggerLogs.insert(0, log);
  }

  /// max events from background stored in Shared
  static int maxSharedCount = 50;

  /// max events to be displayed
  static int maxWidgetCount = 200;

  /// backgroundLogger does not render widgets or render from Shared,
  /// but renders only to Shared
  /// To be different from background logger
  static String globalPrefix = '##';
  static bool globalBackgroundLogger = false;
  static LogLevel globalLogLevel = LogLevel.verbose;

  String prefix = globalPrefix;
  bool backGroundLogger = globalBackgroundLogger;
  LogLevel logLevel = globalLogLevel;

  static final Map<String, Logger> _loggerRegister = {};

  bool loggerEnabled = true;

  /// Class name of what class created the logger.
  /// defaults to Logger
  String _loggerName = 'Logger'; // ignore: prefer_final_fields
  String get loggerId => _loggerName;

  static String get time {
    DateTime t = DateTime.now();
    var m = t.minute;
    var s = t.second;
    var ms = t.millisecond;
    return '$m:$s.$ms';
  }

  /// constructor
  static Logger logger<T>(
      {String? specialPrefix,
      bool? specialBackgroundLogger,
      LogLevel? specialLogLevel}) {
    Logger l = Logger();
    l.prefix = specialPrefix ?? globalPrefix;
    l.backGroundLogger = specialBackgroundLogger ?? globalBackgroundLogger;
    l.logLevel = specialLogLevel ?? globalLogLevel;
    String n = T.toString();
    l._loggerName = n;
    _loggerRegister[n] = l;
    //l.log('Logger for class $n created');
    return l;
  }

  /// Usage:
  /// ```
  /// MyClass{
  ///   static final Logger logger = Logger.logger<MyClass>();
  /// ```
  Logger();

  Future<void> verbose(Object msg) =>
      Future.microtask(() => _log(LogLevel.verbose, msg.toString()));
  //
  Future<void> log(Object msg) =>
      Future.microtask(() => _log(LogLevel.log, msg.toString()));
  //
  Future<void> important(Object msg) =>
      Future.microtask(() => _log(LogLevel.important, msg.toString()));
  //
  Future<void> warn(Object msg) =>
      Future.microtask(() => _log(LogLevel.warn, msg.toString()));
  //
  Future<void> error(Object msg, StackTrace? stackTrace) => Future.microtask(
      () => _log(LogLevel.error, msg.toString(), stackTrace.toString()));
  //
  Future<void> fatal(Object msg, StackTrace? stackTrace) => Future.microtask(
      () => _log(LogLevel.fatal, msg.toString(), stackTrace.toString()));

  /// main log method
  _log(LogLevel level, String msg, [String? stackTrace]) {
    if (level.level >= logLevel.level && loggerEnabled) {
      try {
        print(
            '$prefix ${composeMessage(_loggerName, level, msg, stackTrace)}'); // ignore: avoid_print
      } catch (e) {
        // ignore
      }
      if (backGroundLogger) {
        _addBackgroundLog(level, msg, stackTrace);
      } else {
        // prevent stack overflow due to EventManager.fire triggers a log
        addLoggerLog(LoggerLog(
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

  _addBackgroundLog(LogLevel level, String msg, String? stackTrace) async {
    try {
      // ignore: unused_local_variable
      List<String> parts = [
        Uri.encodeFull(DateTime.now().toIso8601String()),
        Uri.encodeFull(prefix),
        Uri.encodeFull(_loggerName),
        Uri.encodeFull(level.name),
        Uri.encodeFull(msg),
        Uri.encodeFull(stackTrace.toString()),
        '|'
      ];

      List<String> list =
          await Cache.getValue<List<String>>(CacheKeys.backgroundLogger, []);
      while (list.length >= maxSharedCount) {
        list.removeLast();
      }
      list.insert(0, parts.join('\t'));
      await Cache.setValue<List<String>>(CacheKeys.backgroundLogger, list);
    } catch (e, stk) {
      _exceptionLogger.error('_addSharedLog: $e', stk);
    }
  }

  /// fires
  static Future<void> getBackgroundLogs() async {
    List<String> list =
        await Cache.getValue<List<String>>(CacheKeys.backgroundLogger, []);
    // reset list
    await Cache.setValue<List<String>>(CacheKeys.backgroundLogger, []);
    List<LoggerLog> logs = [];
    for (var item in list) {
      try {
        List<String> p = item.split('\t');
        DateTime time = DateTime.parse(Uri.decodeFull(p[0]));
        String prefix = Uri.decodeFull(p[1]);
        String loggerName = Uri.decodeFull(p[2]);
        LogLevel level = LogLevel.values.byName(Uri.decodeFull(p[3]));
        String msg = Uri.decodeFull(p[4]);
        String stackTrace = Uri.decodeFull(p[5]);
        var log = LoggerLog(
            logger: _logger,
            prefix: prefix,
            name: loggerName,
            level: level,
            msg: msg,
            stackTrace: stackTrace);
        log.time = time;
        addLoggerLog(log);
      } catch (e, stk) {
        _exceptionLogger.error('renderSharedLog: $e \non item:\n $item', stk);
      }
    }
  }

/*
  ///
  /// example widget renderer
  ///
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
*/
}
