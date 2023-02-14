import 'package:flutter/material.dart';
import 'package:chaostours/widget/widgets.dart';
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
    var divider = AppWidgets.divider();
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
      const Text('Chaos Tours'),
      divider,

      ///
      ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.home.route);
          },
          child: const Text('Tracking')),
      divider,

      ///
      ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.permissions.route);
          },
          child: const Text('Android Permissions')),
      divider,

      ///
      ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.logger.route);
          },
          child: const Text('Logger')),
      divider,

      ///
      ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.listUsers.route);
          },
          child: const Text('Personal')),

      ///
      ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.listTasks.route);
          },
          child: const Text('Aufgaben')),

      ///
      ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.listAlias.route);
          },
          child: const Text('Orte (Alias)')),
    ]));
  }
}
