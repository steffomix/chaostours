import 'package:chaostours/event_manager.dart';

enum LogLevel {
  verbose(0),
  log(1),
  warn(2),
  error(3),
  fatal(4);

  final int level;
  const LogLevel(this.level);
}

class Logger {
  static LogLevel logLevel = LogLevel.log;
  static Function(String) printerVerbose = print;
  static Function(String) printerLog = print;
  static Function(String) printerWarn = print;
  static Function(String) printerError = print;
  static Function(String) printerFatal = print;

  static void mute() {
    printerVerbose = printerLog =
        printerWarn = printerError = printerFatal = (String msg) {};
  }

  static void unMute() {
    printerVerbose =
        printerLog = printerWarn = printerError = printerFatal = print;
  }

  String rt = ''; // runtimeType
  static Logger logger<T>() {
    Logger l = Logger();
    l.rt = T.runtimeType.toString();
    return l;
  }

  void logVerbose(String msg) {
    EventManager.fire<EventLogVerbose>(EventLogVerbose(msg));
    if (logLevel.level <= 0) {
      printerVerbose('Verbose: $rt: $msg');
    }
  }

  void log(String msg) {
    EventManager.fire<EventLog>(EventLog(msg));
    if (logLevel.level <= 1) {
      printerLog('Log: $rt: $msg');
    }
  }

  void logWarn(String msg) {
    EventManager.fire<EventLogWarn>(EventLogWarn(msg));
    if (logLevel.level <= 2) {
      printerError('Warning $rt: $msg');
    }
  }

  void logError(String msg, StackTrace? stackTrace) {
    EventManager.fire<EventLogError>(EventLogError(msg, stackTrace));
    String stk = '$stackTrace'.trim();
    if (logLevel.level <= 3) {
      printerError('Error $rt: $msg ${stk.isEmpty ? '' : '\n$stk'}');
    }
  }

  void logFatal(String msg, StackTrace? stackTrace) {
    EventManager.fire<EventLogFatal>(EventLogFatal(msg, stackTrace));
    String stk = '$stackTrace'.trim();
    if (logLevel.level <= 4) {
      printerFatal('Fatal Error $rt: $msg ${stk.isEmpty ? '' : '\n$stk'}');
    }
  }
}

class EventLogVerbose {
  String msg;
  EventLogVerbose(this.msg);
}

class EventLog {
  String msg;
  EventLog(this.msg);
}

class EventLogWarn {
  String msg;
  EventLogWarn(this.msg);
}

class EventLogError {
  String msg;
  StackTrace? stacktrace;
  EventLogError(this.msg, [this.stacktrace]);
}

class EventLogFatal {
  String msg;
  StackTrace? stacktrace;
  EventLogFatal(this.msg, [this.stacktrace]);
}
