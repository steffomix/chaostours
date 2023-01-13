import 'package:flutter/material.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/logger.dart';

class WidgetLogger extends StatefulWidget {
  const WidgetLogger({super.key});

  @override
  State<WidgetLogger> createState() => _WidgetLogger();
}

class _WidgetLogger extends State<WidgetLogger> {
  static List<Widget> logs = [];
  static _WidgetLogger? _instance;
  _WidgetLogger._();
  factory _WidgetLogger() => _instance ??= _WidgetLogger._();

  Widget createMessage(String msg) {
    return Container(
        color: Colors.grey,
        child: Text(msg, style: const TextStyle(color: Colors.blue)));
  }

  void onLog(EventOnLog event) {
    setState(() {
      logs.add(createMessage(event.msg));
    });
  }

  void onLogVerbose(EventOnLogVerbose event) {}
  void onLogDefault(EventOnLogDefault event) {}
  void onLogWarn(EventOnLogDefault event) {}
  void onLogError(EventOnLogError event) {}
  void onLogFatal(EventOnLogFatal event) {}

  @override
  Widget build(BuildContext context) {
    return ListView(children: logs.reversed.toList());
  }
}
