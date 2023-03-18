import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
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
  Widget widgetPermissions = AppWidgets.loading('Checking Permissions');
  bool permissionChecked = false;
  List<Widget> items = [];

  @override
  void initState() {
    _permissionItems().then((_) {
      renderBody();
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void permissionItems() {
    _permissionItems().then((_) {
      renderBody();
    });
  }

  Future<void> _permissionItems() async {
    items.clear();
    if (!(await Permission.location.isGranted)) {
      items.add(ListTile(
          leading: (await Permission.location.isGranted)
              ? const Icon(Icons.done)
              : const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Einfache (Vordergrund) GPS Ortung nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AppSettings.openLocationSettings(
                  asAnotherTask: false,
                  callback: () {
                    permissionItems();
                  });
            },
          )));
    }
    if (!(await Permission.locationAlways.isGranted)) {
      items.add(ListTile(
          leading: (await Permission.locationAlways.isGranted)
              ? const Icon(Icons.done)
              : const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Hintergrund GPS Ortung nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AppSettings.openLocationSettings(
                  asAnotherTask: false,
                  callback: () {
                    permissionItems();
                  });
            },
          )));
    }
    if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {
      items.add(ListTile(
          leading: (await Permission.ignoreBatteryOptimizations.isGranted)
              ? const Icon(Icons.done)
              : const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Ignorieren der Batterieoptimierung nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AppSettings.openBatteryOptimizationSettings(
                  asAnotherTask: false,
                  callback: () {
                    permissionItems();
                  });
            },
          )));
    }
    if (!(await Permission.storage.isGranted)) {
      items.add(ListTile(
          leading: (await Permission.storage.isGranted)
              ? const Icon(Icons.done)
              : const Icon(Icons.error_outline, color: Colors.red),
          title:
              const Text('Zugriff auf App-Internes Dateisystem nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AppSettings.openInternalStorageSettings(
                  asAnotherTask: false,
                  callback: () {
                    permissionItems();
                  });
            },
          )));
    }
    if (!(await Permission.manageExternalStorage.isGranted)) {
      items.add(ListTile(
          leading: (await Permission.manageExternalStorage.isGranted)
              ? const Icon(Icons.done)
              : const Icon(Icons.error_outline, color: Colors.red),
          title:
              const Text('Zugriff auf App-Externes Dateisystem nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AppSettings.openAppSettings(
                  asAnotherTask: false,
                  callback: () {
                    permissionItems();
                  });
            },
          )));
    }
    if (!(await Permission.notification.isGranted)) {
      items.add(ListTile(
          leading: (await Permission.notification.isGranted)
              ? const Icon(Icons.done)
              : const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Anzeige von App-Meldungen nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AppSettings.openNotificationSettings(
                  asAnotherTask: false,
                  callback: () {
                    permissionItems();
                  });
            },
          )));
    }
    if (!(await Permission.calendar.isGranted)) {
      items.add(ListTile(
          leading: (await Permission.calendar.isGranted)
              ? const Icon(Icons.done)
              : const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Zugriff auf Geräte-Kalender nicht erlaubt'),
          subtitle: const Text(''),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AppSettings.openAppSettings(
                  asAnotherTask: false,
                  callback: () {
                    permissionItems();
                  });
            },
          )));
    }
    Future.delayed(const Duration(seconds: 1), permissionItems);
  }

  void renderBody() {
    widgetPermissions = ListView(children: [...items]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context, body: widgetPermissions);
  }
}
