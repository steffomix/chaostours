// ignore_for_file: deprecated_member_use

/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:permission_handler/permission_handler.dart';
import 'package:chaostours/channel/background_channel.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
//

@override
class WidgetPermissionsPage extends StatefulWidget {
  const WidgetPermissionsPage({super.key});
  @override
  State<WidgetPermissionsPage> createState() => _WidgetPermissionsPage();
}

class _WidgetPermissionsPage extends State<WidgetPermissionsPage> {
  Logger logger = Logger.logger<WidgetPermissionsPage>();
  Widget widgetPermissions = AppWidgets.loading(const Text(''));
  //BuildContext? _context;
  List<Widget> items = [];

  bool permLocation = false;
  //bool permLocationAlways = false;
  bool permIgnoreBattery = false;
  //bool permManageExternalStorage = false;
  bool permNotification = false;
  bool permCalendar = false;

  @override
  void initState() {
    updatePermissionsInfo('Checking Permissions');
    permissionItems();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool> checkAll() async {
    if (!(await Permission.location.isGranted)) {
      return false;
    }
    if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {
      return false;
    }
    if (!(await Permission.notification.isGranted)) {
      return false;
    }
    try {
      if (!(await Permission.calendar.isGranted)) {
        return false;
      }
    } catch (e) {
      if (!(await Permission.calendarFullAccess.isGranted)) {
        return false;
      }
    }
    return true;
  }

  Future<void> requestAll() async {
    await Permission.location.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.notification.request();
    try {
      await Permission.calendar.request();
    } catch (e) {
      await Permission.calendarFullAccess.request();
    }
    renderBody();
  }

  void updatePermissionsInfo(String info) {
    widgetPermissions = AppWidgets.loading(Text(info));
  }

  void permissionItems() {
    _permissionItems(checkPermissions: true).then((_) {
      renderBody();
    }).onError((error, stackTrace) {
      logger.error(error.toString(), stackTrace);
      renderBody();
    });
  }

  Future<void> _permissionItems({bool checkPermissions = false}) async {
    items.clear();

    if (checkPermissions) {
      await showAwesomePermissionCheck();
    }

    bool isTracking = await BackgroundChannel.isRunning();
    items.add(ListTile(
        leading: isTracking
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('State of Background Tracking'),
        subtitle: const Text('Start/Stop Tracking.'),
        trailing: IconButton(
          icon: isTracking
              ? const Icon(Icons.stop)
              : const Icon(Icons.play_arrow),
          onPressed: () async {
            if (isTracking) {
              await BackgroundChannel.stop();
            } else {
              await BackgroundChannel.start();
            }
            await _permissionItems();
            Future.delayed(const Duration(milliseconds: 100), () {
              renderBody();
            });
          },
        )));

    items.add(AppWidgets.divider());

    ///
    ///
    items.add(Center(
        child: FilledButton(
            onPressed: () {
              _permissionItems(checkPermissions: true).then((_) {
                renderBody();
              });
            },
            child: const Text('Repeat Check Permissions'))));
    if (!await checkAll()) {
      items.add(Center(
          child: FilledButton(
              onPressed: () async {
                requestAll();
              },
              child: const Text('Request all Permissions'))));
    }
    items.add(ListTile(
        leading: permLocation
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('GPS location'),
        subtitle: const Text('Used for location lookup.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            AppWidgets.requestLocation(context);
          },
        )));

    items.add(ListTile(
        leading: permIgnoreBattery
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Ignore battery optimization.'),
        subtitle: const Text('Prevents your device to put this app to sleep.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Permission.ignoreBatteryOptimizations.request();
          },
        )));

    items.add(ListTile(
        leading: permNotification
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Notifications.'),
        subtitle: const Text(
            'Keeps this app up and running and provides some app status information.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Permission.notification.request();
          },
        )));

    items.add(ListTile(
        leading: permCalendar
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('(Optional) Device calendar.'),
        subtitle: const Text('Used to pl.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            try {
              await Permission.calendar.request();
            } catch (e) {
              await Permission.calendarFullAccess.request();
            }
          },
        )));
  }

  void renderBody() {
    widgetPermissions = ListView(children: [...items]);
    setState(() {});
  }

  Future<void> showAwesomePermissionCheck() async {
    Duration wait = const Duration(milliseconds: 150);
    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission GPS Loation');
        }));
    await Future.delayed(wait);
    permLocation = await Permission.location.isGranted;
    await Future.delayed(wait);
    permIgnoreBattery = await Permission.ignoreBatteryOptimizations.isGranted;
    await Future.delayed(wait);
    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Notification');
        }));
    await Future.delayed(wait);
    permNotification = await Permission.notification.isGranted;

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Manage Calendar');
        }));
    await Future.delayed(wait);
    try {
      permCalendar = await Permission.calendar.isGranted;
    } catch (e) {
      permCalendar = await Permission.calendarFullAccess.isGranted;
    }
    renderBody();
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: widgetPermissions,
        appBar: AppBar(title: const Text('Permissions')));
  }
}
