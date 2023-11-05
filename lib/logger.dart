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

import 'package:flutter/foundation.dart';

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

class Logger {
  static void debugPrint(Object? msg) {
    if (kDebugMode) {
      print(msg.toString());
    }
  }

  /// but renders only to Shared
  /// To be different from background logger
  static LoggerRealm defaultRealm = LoggerRealm.foreground;
  static bool globalBackgroundLogger = false;
  static LogLevel globalLogLevel = LogLevel.verbose;

  LoggerRealm realm = defaultRealm;
  bool backGroundLogger = globalBackgroundLogger;
  LogLevel logLevel = globalLogLevel;

  bool loggerIsEnabled = true;

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
    l._loggerName = T.toString();
    return l;
  }

  /// Usage:
  /// ```
  /// MyClass{
  ///   static final logger = Logger.logger<MyClass>();
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
    if (level.level >= logLevel.level && loggerIsEnabled) {
      try {
        debugPrint(
            '${realm.prefix} ${composeMessage(_loggerName, level, msg, stackTrace)}'); // ignore: avoid_print
      } catch (e, stk) {
        debugPrint('Logger Error: $e\n${stk.toString()}');
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
}
