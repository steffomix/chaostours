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
  _WidgetLogger() {
    EventManager.listen<EventOnLog>(onLog);
  }

  @override
  void dispose() {
    EventManager.remove<EventOnLog>(onLog);
    super.dispose();
  }

  void onLog(EventOnLog event) => mounted ? setState(() {}) : () {};

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      ...Logger.widgetLogs.reversed.toList(),
      Text('Waiting for Logs...${Logger.widgetLogs.length}')
    ]);
  }
}
