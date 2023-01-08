import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/enum.dart';

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

class _WidgetDrawer extends State<WidgetDrawer> {
  void onPressedTracking(BuildContext ctx) {
    eventBusMainPaneChanged.fire(Panes.trackPointList.value);
    Navigator.pop(ctx);
  }

  void onPressedPermissions(BuildContext ctx) {
    eventBusMainPaneChanged.fire(Panes.permissions.value);
    Navigator.pop(ctx);
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
          child: const Text('Android Permissions'))
    ]));
  }
}
