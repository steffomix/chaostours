import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chaostours/notifications.dart';
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
  bool permissionChecked = false;

  @override
  void initState() {
    permissionItems();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget widgetPermissions = AppWidgets.loading('Checking Permissions');

  Future<void> permissionItems() async {
    List<Widget> items = [];
    if (!(await Permission.location.isGranted)) {
      items.add(ListTile(
          leading:
              const Text('Einfache (Vordergrund) GPS Ortung nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )));
    }
    if (!(await Permission.locationAlways.isGranted)) {
      items.add(ListTile(
          leading: const Text('Hintergrund GPS Ortung nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )));
    }
    if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {
      items.add(ListTile(
          leading:
              const Text('Ignorieren der Batterieoptimierung nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )));
    }
    if (!(await Permission.storage.isGranted)) {
      items.add(ListTile(
          leading:
              const Text('Zugriff auf App-Internes Dateisystem nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )));
    }
    if (!(await Permission.manageExternalStorage.isGranted)) {
      items.add(ListTile(
          leading:
              const Text('Zugriff auf App-Externes Dateisystem nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )));
    }
    if (!(await Permission.notification.isGranted)) {
      items.add(ListTile(
          leading: const Text('Anzeige von App-Meldungen nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )));
    }
    if (!(await Permission.calendar.isGranted)) {
      items.add(ListTile(
          leading: const Text('Zugriff auf Geräte-Kalender nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )));
    }
    renderBody(items);
    Future.delayed(const Duration(seconds: 1), permissionItems);
  }

  void renderBody(List<Widget> items) {
    widgetPermissions = ListView(children: items);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context, body: widgetPermissions);
  }
}
