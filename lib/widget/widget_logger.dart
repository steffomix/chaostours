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
  _WidgetLogger() {
    EventManager.listen<EventOnLogVerbose>(onLogVerbose);
    EventManager.listen<EventOnLogDefault>(onLogDefault);
    EventManager.listen<EventOnLogWarn>(onLogWarn);
    EventManager.listen<EventOnLogError>(onLogError);
    EventManager.listen<EventOnLogFatal>(onLogFatal);
  }

  @override
  void dispose() {
    EventManager.remove<EventOnLogVerbose>(onLogVerbose);
    EventManager.remove<EventOnLogDefault>(onLogDefault);
    EventManager.remove<EventOnLogWarn>(onLogWarn);
    EventManager.remove<EventOnLogError>(onLogError);
    EventManager.remove<EventOnLogFatal>(onLogFatal);
    super.dispose();
  }

  void onLogVerbose(EventOnLogVerbose event) {
    if (mounted) {
      setState(() {
        //addLog(createLogVerbose(event.msg));
      });
    }
  }

  void onLogDefault(EventOnLogDefault event) {
    if (mounted) {
      setState(() {
        //addLog(createLogDefault(event.msg));
      });
    }
  }

  void onLogWarn(EventOnLogWarn event) {
    if (mounted) {
      setState(() {
        //addLog(createLogWarn(event.msg));
      });
    }
  }

  void onLogError(EventOnLogError event) {
    if (mounted) {
      setState(() {
        //addLog(createLogError(event.msg, event.stacktrace));
      });
    }
  }

  void onLogFatal(EventOnLogFatal event) {
    if (mounted) {
      setState(() {
        //addLog(createLogFatal(event.msg, event.stacktrace));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      ...Logger.widgetLogs.reversed.toList(),
      Text('Waiting for Logs...${Logger.widgetLogs.length}')
    ]);
  }
}
