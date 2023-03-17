//
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/shared.dart';

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

var _print = print;

class Logger {
  static final Logger _logger = Logger.logger<Logger>();
  static void print(Object? msg) {
    _print(msg);
  }

  static listenOnTick() {
    EventManager.listen<EventOnAppTick>(onTick);
  }

  static Future<void> onTick(EventOnAppTick event) async {
    /// render events from background thread
    //print('§§ Logger.onTick()');
    _renderSharedLogs();
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
  bool loggerEnabled = true;

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
  ///   static final Logger logger = Logger.logger<MyClass>();
  /// ```
  Logger();

  Future<void> verbose(String msg) =>
      Future.microtask(() => _log(LogLevel.verbose, msg));
  //
  Future<void> log(String msg) =>
      Future.microtask(() => _log(LogLevel.log, msg));
  //
  Future<void> important(String msg) =>
      Future.microtask(() => _log(LogLevel.important, msg));
  //
  Future<void> warn(String msg) =>
      Future.microtask(() => _log(LogLevel.warn, msg));
  //
  Future<void> error(String msg, StackTrace? stackTrace) =>
      Future.microtask(() => _log(LogLevel.error, msg, stackTrace.toString()));
  //
  Future<void> fatal(String msg, StackTrace? stackTrace) =>
      Future.microtask(() => _log(LogLevel.fatal, msg, stackTrace.toString()));

  /// main log method
  _log(LogLevel level, String msg, [String? stackTrace]) {
    if (level.level >= logLevel.level && loggerEnabled) {
      try {
        print(
            '$prefix ${composeMessage(_name, level, msg, stackTrace)}'); // ignore: avoid_print
      } catch (e) {
        // ignore
      }
      if (backgroundLogger) {
        _addSharedLog(level, msg, stackTrace);
      } else {
        // prevent stack overflow due to EventManager.fire triggers a log
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

  _addSharedLog(LogLevel level, String msg, String? stackTrace) async {
    List<String> parts = [
      Uri.encodeFull(prefix),
      Uri.encodeFull(_name),
      Uri.encodeFull(level.name),
      Uri.encodeFull(msg),
      Uri.encodeFull('$stackTrace'),
      '|'
    ];
    Shared shared = Shared(SharedKeys.workmanagerLogger);
    List<String> list = (await shared.loadList()) ?? [];
    while (list.length >= maxSharedCount) {
      list.removeLast();
    }
    list.add(parts.join('\t'));
    await shared.saveList(list);
  }

  static Future<void> _renderSharedLogs() async {
    Shared shared = Shared(SharedKeys.workmanagerLogger);
    List<String> list = (await shared.loadList()) ?? [];
    await shared.saveList(<String>[]);
    for (var item in list) {
      try {
        List<String> p = item.split('\t');
        String prefix = Uri.decodeFull(p[0]);
        String loggerName = Uri.decodeFull(p[1]);
        LogLevel level = LogLevel.values.byName(Uri.decodeFull(p[2]));
        String msg = Uri.decodeFull(p[3]);
        String stackTrace = Uri.decodeFull(p[4]);
        //msg = composeMessage(loggerName, level, msg, stackTrace);
        EventManager.fire<EventOnLog>(EventOnLog(
            logger: _logger,
            prefix: prefix,
            name: loggerName,
            level: level,
            msg: msg,
            stackTrace: stackTrace));
        //_addLogWidget(renderLog(prefix, level, msg));
      } catch (e, stk) {
        _logger.error('render shared log: $item', null);
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
