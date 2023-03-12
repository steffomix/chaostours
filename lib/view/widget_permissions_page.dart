import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chaostours/notifications.dart';
import 'package:app_settings/app_settings.dart';
//
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';

//
import 'package:chaostours/view/app_widgets.dart';

@override
class WidgetPermissionsPage extends StatefulWidget {
  const WidgetPermissionsPage({super.key});
  @override
  State<WidgetPermissionsPage> createState() => _WidgetPermissionsPage();
}

class _WidgetPermissionsPage extends State<WidgetPermissionsPage> {
  @override
  void initState() {
    permissionItems();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget body = AppWidgets.loading('Checking Permissions');

  Future<void> permissionItems() async {
    List<Widget> items = [];
    if (!(await Permission.location.isGranted)) {
      items.add(ListTile(
          leading: const Text('Einfache GPS Ortung nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => AppSettings.openLocationSettings(),
          )));
    }
    body = Container(child: Column(children: items));
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context, body: body);
  }
}
