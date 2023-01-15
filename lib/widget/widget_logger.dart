import 'package:flutter/material.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared_model/shared.dart';

class WidgetLogger extends StatefulWidget {
  const WidgetLogger({super.key});

  @override
  State<WidgetLogger> createState() => _WidgetLogger();
}

class _WidgetLogger extends State<WidgetLogger> {
  _WidgetLogger() {
    EventManager.listen<EventOnLog>(onLog);
  }

  @override
  void dispose() {
    EventManager.remove<EventOnLog>(onLog);
    super.dispose();
  }

  static Widget renderLog(
      String name, String level, String msg, String stackTrace) {
    String stk = '';
    if (stackTrace.isNotEmpty) {
      stk = '\n$stackTrace';
    }
    msg = '~~ $time ::${level} $time<$name>:: $msg$stk';
    switch (level) {
      case 'verbose':
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black45)));

      case 'log':
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.white,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case 'important':
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.greenAccent,
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)));

      case 'warn':
        return Container(
            margin: const EdgeInsets.only(top: 6),
            color: Colors.yellow,
            child: Text(msg, style: const TextStyle(color: Colors.black)));

      case 'error':
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

  static String get time {
    DateTime t = DateTime.now();
    var s = t.second;
    var ms = t.millisecond;
    return '$s:$ms';
  }

  static List<Widget> backLog = [];

  void onLog(EventOnLog event) => mounted ? setState(() {}) : () {};

  @override
  Widget build(BuildContext context) {
    //renderBackLog();
    return ListView(children: [
      ...Logger.widgetLogs.reversed.toList(),
      Text('Waiting for Logs...${Logger.widgetLogs.length}')
    ]);
  }
}
