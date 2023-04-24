import 'dart:async';

import 'package:chaostours/background_process/tracking.dart';
import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'package:chaostours/file_handler.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/permission_checker.dart';

//

@override
class WidgetPermissionsPage extends StatefulWidget {
  const WidgetPermissionsPage({super.key});
  @override
  State<WidgetPermissionsPage> createState() => _WidgetPermissionsPage();
}

class _WidgetPermissionsPage extends State<WidgetPermissionsPage> {
  Logger logger = Logger.logger<WidgetPermissionsPage>();
  Widget widgetPermissions = AppWidgets.loading('');
  BuildContext? _context;
  List<Widget> items = [];

  bool permLocation = false;
  bool permLocationAlways = false;
  bool permIgnoreBattery = false;
  bool permStorage = FileHandler.storageKey != Storages.notSet;
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

  void updatePermissionsInfo(String info) {
    widgetPermissions = AppWidgets.loading(info);
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
              await BackgroundTracking.initialize();
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
    if (FileHandler.storageKey == Storages.notSet) {
      items.add(ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Kein Speicherort gesetzt'),
          subtitle: const Text('Wird benötigt, um Daten zu speichern.'),
          trailing: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                if (_context != null) {
                  Navigator.pushNamed(
                          _context!, AppRoutes.storageSettings.route)
                      .then((_) {
                    _permissionItems().then((_) {
                      renderBody();
                    });
                  });
                }
              })));
    } else {
      items.add(ListTile(
          leading: const Icon(Icons.done, color: Colors.green),
          title: const Text('Speicherort gesetzt'),
          subtitle: Text('${FileHandler.storagePath}'),
          trailing: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                if (_context != null) {
                  Navigator.pushNamed(
                          _context!, AppRoutes.storageSettings.route)
                      .then((_) {
                    _permissionItems().then((_) {
                      renderBody();
                    });
                  });
                }
              })));
    }

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
    if (!await PermissionChecker.checkAll()) {
      items.add(Center(
          child: ElevatedButton(
              onPressed: () {
                PermissionChecker.requestAll();
              },
              child: const Text('Request Permissions'))));
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
            AppSettings.openLocationSettings(asAnotherTask: false);
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
            AppSettings.openLocationSettings(asAnotherTask: false);
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
            AppSettings.openBatteryOptimizationSettings(asAnotherTask: false);
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
            AppSettings.openAppSettings(asAnotherTask: false);
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
            AppSettings.openNotificationSettings(asAnotherTask: false);
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
          onPressed: () {
            AppSettings.openAppSettings(asAnotherTask: false);
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
    permLocation = await PermissionChecker.checkLocation();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission GPS Loation Always');
        }));
    await Future.delayed(wait);
    permLocationAlways = await PermissionChecker.checkLocationAlways();

    Future.microtask(() => setState(() {
          updatePermissionsInfo(
              'Check Permission Ignore Battery Optimizations');
        }));
    await Future.delayed(wait);
    permIgnoreBattery =
        await PermissionChecker.checkIgnoreBatteryOptimizations();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Manage External Storage');
        }));
    await Future.delayed(wait);
    permManageExternalStorage =
        await PermissionChecker.checkManageExternalStorage();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Notification');
        }));
    await Future.delayed(wait);
    permNotification = await PermissionChecker.checkNotification();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Manage Calendar');
        }));
    await Future.delayed(wait);
    permCalendar = await PermissionChecker.checkCalendar();
    renderBody();
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return AppWidgets.scaffold(context, body: widgetPermissions);
  }
}
