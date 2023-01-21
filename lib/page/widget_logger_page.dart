import 'package:flutter/material.dart';
//
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared/shared.dart';
//
import 'package:chaostours/widget/widget_drawer.dart';
import 'package:chaostours/widget/widgets.dart';
import 'package:chaostours/widget/widget_bottom_navbar.dart';

class WidgetLoggerPage extends StatefulWidget {
  const WidgetLoggerPage({super.key});

  @override
  State<WidgetLoggerPage> createState() => _WidgetLoggerPage();
}

class _WidgetLoggerPage extends State<WidgetLoggerPage> {
  _WidgetLoggerPage() {
    EventManager.listen<EventOnTick>(onTick);
    EventManager.listen<EventOnLog>(onLog);
  }
  @override
  void dispose() {
    EventManager.remove<EventOnTick>(onTick);
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

  void onTick(EventOnTick event) {
    //setState(() {});
  }

  void onLog(EventOnLog e) async {
    Widget widget = renderLog(e.prefix, e.level, e.msg, e.stackTrace);
    logs.insert(0, widget);
    while (logs.length > 200) {
      logs.removeLast();
    }
    Shared shared = Shared(SharedKeys.counterWorkmanager);
    counter = await shared.loadInt() ?? 0;
    setState(() {});
  }

  List<Widget> logs = [];
  int counter = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Widgets.appBar(),
      drawer: const WidgetDrawer(),
      body: ListView(children: [Text('Background ticks: $counter'), ...logs]),
      bottomNavigationBar: const WidgetBottomNavBar(),
    );
  }
}