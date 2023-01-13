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
  _WidgetLogger._() {
    EventManager.listen<EventOnLogDefault>(onLogDefault);
  }
  factory _WidgetLogger() => _instance ??= _WidgetLogger._();
  Widget createLogVerbose(String msg) {
    return Container(
        color: Colors.white,
        child: Text(msg, style: const TextStyle(color: Colors.black45)));
  }

  Widget createLogDefault(String msg) {
    return Container(
        color: Colors.white,
        child: Text(msg, style: const TextStyle(color: Colors.black)));
  }

  Widget createLogWarn(String msg) {
    return Container(
        color: Colors.yellow,
        child: Text(msg, style: const TextStyle(color: Colors.black)));
  }

  Widget createLogError(String msg, StackTrace? stackTrace) {
    return Container(
        color: Colors.red,
        child: Text('$msg\n$stackTrace',
            style: const TextStyle(color: Colors.white)));
  }

  Widget createLogFatal(String msg, StackTrace? stackTrace) {
    return Container(
        color: Colors.purple,
        child: Text('$msg\n$stackTrace',
            style: const TextStyle(color: Colors.white)));
  }

  void onLogVerbose(EventOnLogVerbose event) {
    setState(() {
      logs.add(createLogVerbose(event.msg));
    });
  }

  void onLogDefault(EventOnLogDefault event) {
    setState(() {
      logs.add(createLogDefault(event.msg));
    });
  }

  void onLogWarn(EventOnLogWarn event) {
    setState(() {
      logs.add(createLogWarn(event.msg));
    });
  }

  void onLogError(EventOnLogError event) {
    setState(() {
      logs.add(createLogError(event.msg, event.stacktrace));
    });
  }

  void onLogFatal(EventOnLogFatal event) {
    setState(() {
      logs.add(createLogFatal(event.msg, event.stacktrace));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: logs.reversed.toList());
  }
}
