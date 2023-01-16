import 'package:flutter/material.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/shared_model/shared.dart';
import 'package:googleapis/displayvideo/v1.dart';

class WidgetLogger extends StatefulWidget {
  const WidgetLogger({super.key});

  @override
  State<WidgetLogger> createState() => _WidgetLogger();
}

class _WidgetLogger extends State<WidgetLogger> {
  _WidgetLogger() {
    EventManager.listen<EventOnTick>(onLog);
  }

  Widget pane = ListView(children: const [Text('Waiting for Logs')]);

  @override
  void dispose() {
    EventManager.remove<EventOnTick>(onLog);
    super.dispose();
  }

  void onLog(EventOnTick event) {
    pane = ListView(children: const [Text('Waiting for Logs')]);
    setState(() {});
    pane = ListView(children: [...Logger.widgetLogs.reversed.toList()]);
    setState(() {});
  }

  int i = 0;

  @override
  Widget build(BuildContext context) {
    i++;
    List<Widget> list = Logger.getWidgetLogs();
    //renderBackLog();
    return ListView(children: [Container(child: Text('$i')), ...list]);
  }
}
