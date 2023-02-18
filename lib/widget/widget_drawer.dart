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
            AppWidgets.navigate(context, AppRoutes.home);
          },
          child: const Text('Tracking')),
      divider,

      ///
      ElevatedButton(
          onPressed: () {
            AppWidgets.navigate(context, AppRoutes.permissions);
          },
          child: const Text('Android Permissions')),
      divider,

      ///
      ElevatedButton(
          onPressed: () {
            AppWidgets.navigate(context, AppRoutes.logger);
          },
          child: const Text('Logger')),
      divider,

      ///
      ElevatedButton(
          onPressed: () {
            AppWidgets.navigate(context, AppRoutes.listUsers);
          },
          child: const Text('Personal')),

      ///
      ElevatedButton(
          onPressed: () {
            AppWidgets.navigate(context, AppRoutes.listTasks);
          },
          child: const Text('Aufgaben')),

      ///
      ElevatedButton(
          onPressed: () {
            AppWidgets.navigate(context, AppRoutes.listAlias);
          },
          child: const Text('Orte (Alias)')),
    ]));
  }
}
