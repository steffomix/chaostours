import 'package:flutter/material.dart';

///
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';

class WidgetLoggerPage extends StatefulWidget {
  const WidgetLoggerPage({super.key});

  @override
  State<WidgetLoggerPage> createState() => _WidgetLoggerPage();
}

class _WidgetLoggerPage extends State<WidgetLoggerPage> {
  _WidgetLoggerPage() {
    EventManager.listen<EventOnAppTick>(onTick);
    EventManager.listen<EventOnLog>(onLog);
  }
  @override
  void dispose() {
    EventManager.remove<EventOnAppTick>(onTick);
    EventManager.remove<EventOnLog>(onLog);
    super.dispose();
  }

  static String get time {
    DateTime t = DateTime.now();
    var m = t.minute;
    var s = t.second;
    var ms = t.millisecond;
    return '$m:$s.$ms';
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

  void onTick(EventOnAppTick event) {
    //setState(() {});
  }

  void onLog(EventOnLog e) async {
    Widget widget = renderLog(e.prefix, e.level,
        composeMessage(e.name, e.level, e.msg, e.stackTrace), e.stackTrace);
    logs.insert(0, widget);
    while (logs.length > 200) {
      logs.removeLast();
    }
    setState(() {});
  }

  List<Widget> logs = [];
  int counter = 0;
  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body:
            ListView(children: [Text('Background ticks: $counter'), ...logs]));
  }
}
