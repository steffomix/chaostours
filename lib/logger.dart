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

enum LoggerRealm {
  background('~~'),
  foreground('##'),
  unknown('???');

  final String prefix;
  const LoggerRealm(this.prefix);

  static LoggerRealm byPrefix(String prefix) {
    for (var realm in LoggerRealm.values) {
      if (realm.prefix == prefix) {
        return realm;
      }
    }
    return LoggerRealm.unknown;
  }
}

class LoggerLog {
  DateTime time = DateTime.now();
  //final Logger logger;
  final LoggerRealm realm;
  final String loggerName;
  final LogLevel level;
  final String msg;
  final String? stackTrace;
  LoggerLog(
      { //required this.logger,
      required this.realm,
      required this.loggerName,
      required this.level,
      required this.msg,
      required this.stackTrace});

  @override
  String toString() {
    return [
      Uri.encodeFull(DateTime.now().toIso8601String()),
      Uri.encodeFull(realm.prefix),
      Uri.encodeFull(loggerName),
      Uri.encodeFull(level.name),
      Uri.encodeFull(msg),
      Uri.encodeFull(stackTrace.toString()),
      '|'
    ].join('\t');
  }

  static LoggerLog toObject(String log) {
    List<String> p = log.split('\t');
    DateTime time = DateTime.parse(Uri.decodeFull(p[0]));
    String realm = Uri.decodeFull(p[1]);
    String loggerName = Uri.decodeFull(p[2]);
    LogLevel level = LogLevel.values.byName(Uri.decodeFull(p[3]));
    String msg = Uri.decodeFull(p[4]);
    String stackTrace = Uri.decodeFull(p[5]);
    var loggerLog = LoggerLog(
        realm: LoggerRealm.byPrefix(realm),
        loggerName: loggerName,
        level: level,
        msg: msg,
        stackTrace: stackTrace);
    loggerLog.time = time;
    return loggerLog;
  }
}

var _print = print;

class Logger {
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
  static LoggerRealm defaultRealm = LoggerRealm.foreground;
  static bool globalBackgroundLogger = false;
  static LogLevel globalLogLevel = LogLevel.verbose;

  LoggerRealm realm = defaultRealm;
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
      {LoggerRealm? realm,
      bool? specialBackgroundLogger,
      LogLevel? specialLogLevel}) {
    Logger l = Logger();
    l.realm = realm ?? defaultRealm;
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

  Future<void> verbose(Object? msg) => Future.microtask(
      () async => await _log(LogLevel.verbose, msg.toString()));
  //
  Future<void> log(Object? msg) =>
      Future.microtask(() async => await _log(LogLevel.log, msg.toString()));
  //
  Future<void> important(Object? msg) => Future.microtask(
      () async => await _log(LogLevel.important, msg.toString()));
  //
  Future<void> warn(Object? msg) =>
      Future.microtask(() async => await _log(LogLevel.warn, msg.toString()));
  //
  Future<void> error(Object? msg, StackTrace? stackTrace) =>
      Future.microtask(() async =>
          await _log(LogLevel.error, msg.toString(), stackTrace.toString()));
  //
  Future<void> fatal(Object? msg, StackTrace? stackTrace) =>
      Future.microtask(() async =>
          await _log(LogLevel.fatal, msg.toString(), stackTrace.toString()));

  /// main log method
  Future<void> _log(LogLevel level, String msg, [String? stackTrace]) async {
    if (level.level >= logLevel.level && loggerEnabled) {
      try {
        print(
            '${realm.prefix} ${composeMessage(_loggerName, level, msg, stackTrace)}'); // ignore: avoid_print

        LoggerLog log = LoggerLog(
            realm: realm,
            loggerName: loggerId,
            level: level,
            msg: msg,
            stackTrace: stackTrace);

        if (backGroundLogger) {
          /// add active log
          await _cacheLog(log, CacheKeys.backgroundLogger);
        } else {
          // prevent stack overflow due to EventManager.fire triggers a log
          addLoggerLog(log);
        }

        /// add errorLog
        if (level.level >= LogLevel.warn.level) {
          await _cacheLog(log, CacheKeys.errorLogs);
        }
      } catch (e, stk) {
        print('Log Error: $e\n${stk.toString()}');
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

  Future<void> _cacheLog(LoggerLog log, CacheKeys key) async {
    await Cache.reload();
    var logs = await Cache.getValue<List<LoggerLog>>(key, []);
    logs.insert(0, log);
    while (logs.length >= maxSharedCount) {
      logs.removeLast();
    }
    await Cache.setValue<List<LoggerLog>>(key, logs);
  }

  /// fires
  static Future<void> getBackgroundLogs() async {
    List<LoggerLog> list =
        await Cache.getValue<List<LoggerLog>>(CacheKeys.backgroundLogger, []);
    // reset list
    await Cache.setValue<List<LoggerLog>>(CacheKeys.backgroundLogger, []);
    for (var item in list) {
      addLoggerLog(item);
    }
  }

  static Future<void> clearLogs() async {
    _loggerLogs.clear();
    await Cache.setValue<List<LoggerLog>>(CacheKeys.backgroundLogger, []);
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
