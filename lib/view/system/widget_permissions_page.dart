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

import 'package:chaostours/tracking.dart';
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
  bool permLocationAlways = false;
  bool permIgnoreBattery = false;
  bool permManageExternalStorage = false;
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
    if (!(await Permission.locationAlways.isGranted)) {
      return false;
    }
    if (!(await Permission.ignoreBatteryOptimizations.isGranted)) {
      return false;
    }
    if (!(await Permission.storage.isGranted)) {
      return false;
    }
    if (!(await Permission.manageExternalStorage.isGranted)) {
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
    await Permission.locationAlways.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
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

    bool isTracking = await BackgroundTracking.isTracking();
    items.add(ListTile(
        leading: isTracking
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Status Hintergrund GPS'),
        subtitle: const Text('Hintergrund GPS starten/stoppen'),
        trailing: IconButton(
          icon: isTracking
              ? const Icon(Icons.stop)
              : const Icon(Icons.play_arrow),
          onPressed: () async {
            if (isTracking) {
              await BackgroundTracking.stopTracking();
            } else {
              await BackgroundTracking.startTracking();
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

    items.add(AppWidgets.divider());

    ///
    ///
    items.add(Center(
        child: ElevatedButton(
            onPressed: () {
              _permissionItems(checkPermissions: true).then((_) {
                renderBody();
              });
            },
            child: const Text('Repeat Check Permissions'))));
    if (!await checkAll()) {
      items.add(Center(
          child: ElevatedButton(
              onPressed: () async {
                requestAll();
              },
              child: const Text('Request all Permissions'))));
    }
    items.add(ListTile(
        leading: permLocation
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Einfache (Vordergrund) GPS Ortung.'),
        subtitle: const Text(
            'Wird für für die Karte und Sortierung der Orte benötigt.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Permission.location.request();
          },
        )));

    items.add(ListTile(
        leading: permLocationAlways
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Hintergrund GPS Ortung.'),
        subtitle: const Text('Das Herz dieser App. Wird für die Ortung, '
            'Status Halten und Status Fahren benötigt.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Permission.locationAlways.request();
          },
        )));
    items.add(ListTile(
        leading: permIgnoreBattery
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Ignorieren der Batterieoptimierung.'),
        subtitle: const Text(
            'Sorgt dafür dass die App nicht vom Android-System abgeschaltet wird.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Permission.ignoreBatteryOptimizations.request();
          },
        )));
    items.add(ListTile(
        leading: permManageExternalStorage
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Zugriff auf App-Externes Dateisystem.'),
        subtitle: const Text(
            'Wird benötigt wenn sie auf ihre Daten von außerhalb diese App zugreifen wollen. '
            'Schauen sie im Hauptmenü unter "Speicherorte" für weitere Optionen.'),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Permission.manageExternalStorage.request();
          },
        )));

    items.add(ListTile(
        leading: permNotification
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Anzeige von App-Meldungen.'),
        subtitle: const Text(
            'Wird benötigt wenn sie über Statuswechsel informiert werden wollen.'),
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
        title: const Text('Zugriff auf Geräte-Kalender.'),
        subtitle: const Text(
            'Wird benötigt, wenn sie Statusereignisse in ihren Kalender eintragen lassen wollen.'),
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

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission GPS Loation Always');
        }));
    await Future.delayed(wait);
    permLocationAlways = await Permission.locationAlways.isGranted;

    Future.microtask(() => setState(() {
          updatePermissionsInfo(
              'Check Permission Ignore Battery Optimizations');
        }));
    await Future.delayed(wait);
    permIgnoreBattery = await Permission.ignoreBatteryOptimizations.isGranted;

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission general Storage access');
        }));
    await Future.delayed(wait);
    permManageExternalStorage = await Permission.storage.isGranted;

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Manage External Storage');
        }));
    await Future.delayed(wait);
    permManageExternalStorage =
        await Permission.manageExternalStorage.isGranted;

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
