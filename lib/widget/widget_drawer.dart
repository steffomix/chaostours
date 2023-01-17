import 'package:flutter/material.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/enum.dart';

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

class _WidgetDrawer extends State<WidgetDrawer> {
  void onPressedTracking(BuildContext ctx) {
    EventManager.fire<EventOnMainPaneChanged>(
        EventOnMainPaneChanged(Panes.instance(Panes.trackPointList)));
    //Navigator.pop(ctx);
  }

  void onPressedPermissions(BuildContext ctx) {
    EventManager.fire<EventOnMainPaneChanged>(
        EventOnMainPaneChanged(Panes.instance(Panes.permissions)));
    Navigator.pop(ctx);
  }

  void onPressedLogger(BuildContext ctx) {
    EventManager.fire<EventOnMainPaneChanged>(
        EventOnMainPaneChanged(Panes.instance(Panes.logger)));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
      const Text('Chaos Tours'),
      ElevatedButton(
          onPressed: () {
            onPressedTracking(context);
          },
          child: const Text('Tracking')),
      ElevatedButton(
          onPressed: () {
            onPressedPermissions(context);
          },
          child: const Text('Android Permissions')),
      ElevatedButton(
          onPressed: () {
            onPressedLogger(context);
          },
          child: const Text('Logger'))
    ]));
  }
}
