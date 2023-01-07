import 'package:flutter/material.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/enum.dart';

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

class _WidgetDrawer extends State<WidgetDrawer> {
  void onPressedTracking() =>
      eventBusMainPaneChanged.fire(Panes.trackPointList.value);

  void onPressedPermissions() =>
      eventBusMainPaneChanged.fire(Panes.permissions.value);
  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
      const Text('Chaos Tours'),
      ElevatedButton(
          onPressed: onPressedTracking, child: const Text('Tracking')),
      ElevatedButton(
          onPressed: onPressedPermissions,
          child: const Text('Android Permissions'))
    ]));
  }
}
