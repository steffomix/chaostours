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
    EventManager.listen<EventOnTick>(onTick);
    EventManager.listen<EventOnLog>(onLog);
  }

  Widget pane = ListView(children: const [Text('Waiting for Logs')]);

  @override
  void dispose() {
    EventManager.remove<EventOnTick>(onTick);
    EventManager.remove<EventOnLog>(onLog);
    super.dispose();
  }

  void onTick(EventOnTick event) {}

  void onLog(EventOnLog e) {
    setState(() {});
  }

  int i = 0;
  int i2 = 5;
  List<Widget> logs = [];
  @override
  Widget build(BuildContext context) {
    logs.add(Text('$i'));
    if (logs.length > 10) logs = [];
    i++;
    i2++;
    //renderBackLog();
    return ListView(children: [Text('$i'), Text('$i2'), ...logs]);
  }
}
