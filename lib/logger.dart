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
  static Function(String) printerVerbose = printMessage;
  static Function(String) printerLog = printMessage;
  static Function(String) printerWarn = printMessage;
  static Function(String, StackTrace?) printerError = printError;
  static Function(String, StackTrace?) printerFatal = printError;
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

  //
  static Logger logger<T>() {
    Logger l = Logger();
    String n = T.toString();
    l.log('Logger for class $n created');
    l._name = n;
    _logger[n] = l;
    return l;
  }

  static String get _prefix {
    return '$prefix $time ::';
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
    msg = '$_prefix <$_name>:: $msg';
    EventManager.fire<EventOnLogVerbose>(EventOnLogVerbose(msg));
    if (logLevel.level <= 0 && enabled) {
      printerVerbose(msg);
    }
  }

  void log(String msg, [fireEvent = true]) {
    msg = '$_prefix <$_name>:: $msg';
    if (fireEvent) {
      EventManager.fire<EventOnLogDefault>(EventOnLogDefault(msg));
    }
    if (logLevel.level <= 1 && enabled) {
      printerLog(msg);
    }
  }

  void warn(String msg) {
    msg = '$_prefix <$_name>:: $msg';
    EventManager.fire<EventOnLogWarn>(EventOnLogWarn(msg));
    if (logLevel.level <= 2 && enabled) {
      printerWarn(msg);
    }
  }

  void error(String msg, StackTrace? stackTrace) {
    msg = '$_prefix <$_name>:: $msg';
    EventManager.fire<EventOnLogError>(EventOnLogError(msg, stackTrace));
    if (logLevel.level <= 3 && enabled) {
      printerError(msg, stackTrace);
    }
  }

  void fatal(String msg, StackTrace? stackTrace) {
    msg = '$_prefix <$_name>:: $msg';
    EventManager.fire<EventOnLogFatal>(EventOnLogFatal(msg, stackTrace));
    if (logLevel.level <= 4 && enabled) {
      printerFatal(msg, stackTrace);
    }
  }
}
