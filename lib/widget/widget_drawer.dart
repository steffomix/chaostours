import 'package:flutter/material.dart';
import 'package:chaostours/page/widget_tracking_page.dart';
import 'package:chaostours/page/widget_permissions_page.dart';
import 'package:chaostours/page/widget_logger_page.dart';

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

class _WidgetDrawer extends State<WidgetDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
      const Text('Chaos Tours'),
      ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const WidgetTrackingPage()),
            );
          },
          child: const Text('Tracking')),
      ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const WidgetPermissionsPage()),
            );
          },
          child: const Text('Android Permissions')),
      ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WidgetLoggerPage()),
            );
          },
          child: const Text('Logger'))
    ]));
  }
}
