import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';

enum LogLevel {
  verbose(0),
  log(1),
  warn(2),
  error(3),
  fatal(4),
  off(5);

  final int level;
  const LogLevel(this.level);
}

class Logger {
  static final Logger _selfLogger = logger<Logger>();
  static Function(String) printerVerbose = printMessage;
  static Function(String) printerLog = printMessage;
  static Function(String) printerWarn = printMessage;
  static Function(String, StackTrace?) printerError = printError;
  static Function(String, StackTrace?) printerFatal = printError;
  static LogLevel logLevel = LogLevel.log;
  static final Map<String, Logger> _logger = {};
  static List<String> get names => _logger.keys.toList();
  static Logger? getLoggerByName(String name) => _logger[name];
  bool addLevel = true;
  String prefix = '#';
  bool enabled = true;
  String _name = ''; // runtimeType
  String get name => _name;

  String get time {
    DateTime t = DateTime.now();
    var s = t.second;
    var ms = t.millisecond;
    return '$s:$ms';
  }

  //
  static Logger logger<T>() {
    Logger logger = Logger();
    String n = logger._name = T.runtimeType.toString();
    _logger[logger._name] = logger;
    _selfLogger.verbose('Logger $n created');
    return logger;
  }

  static void printMessage(String msg) {
    try {
      // ignore: avoid_print
      print(msg);
    } catch (e) {
      // ignore
    }
  }

  static void printError(String msg, StackTrace? stk) {
    try {
      // ignore: avoid_print
      print('$msg\n$stk');
    } catch (e) {
      // ignore
    }
  }

  void verbose(String msg) {
    EventManager.fire<EventOnLogVerbose>(EventOnLogVerbose(msg));
    if (logLevel.level <= 0 && enabled) {
      printerVerbose('$time Verbose: $_name: $msg');
    }
  }

  void log(String msg) {
    EventManager.fire<EventOnLogDefault>(EventOnLogDefault(msg));
    if (logLevel.level <= 1 && enabled) {
      printerLog('$time Log: $_name: $msg');
    }
  }

  void warn(String msg) {
    EventManager.fire<EventOnLogWarn>(EventOnLogWarn(msg));
    if (logLevel.level <= 2 && enabled) {
      printerWarn('$time Warning $_name: $msg');
    }
  }

  void error(String msg, StackTrace? stackTrace) {
    EventManager.fire<EventOnLogError>(EventOnLogError(msg, stackTrace));
    if (logLevel.level <= 3 && enabled) {
      printerError('$time Error $_name: $msg', stackTrace);
    }
  }

  void fatal(String msg, StackTrace? stackTrace) {
    EventManager.fire<EventOnLogFatal>(EventOnLogFatal(msg, stackTrace));
    if (logLevel.level <= 4 && enabled) {
      printerFatal('$time Fatal Error $_name: $msg', stackTrace);
    }
  }
}
