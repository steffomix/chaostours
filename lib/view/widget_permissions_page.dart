import 'dart:async';

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
    _permissionItems().then((_) {
      renderBody();
    }).onError((error, stackTrace) {
      logger.error(error.toString(), stackTrace);
      renderBody();
    });
  }

  Future<void> _permissionItems() async {
    int wait = 150;
    items.clear();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission GPS Loation');
        }));
    await Future.delayed(Duration(milliseconds: wait));
    bool permLocation = await PermissionChecker.checkLocation();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission GPS Loation Always');
        }));
    await Future.delayed(Duration(milliseconds: wait));
    bool permLocationAlways = await PermissionChecker.checkLocationAlways();

    Future.microtask(() => setState(() {
          updatePermissionsInfo(
              'Check Permission Ignore Battery Optimizations');
        }));
    await Future.delayed(Duration(milliseconds: wait));
    bool permIgnoreBattery =
        await PermissionChecker.checkIgnoreBatteryOptimizations();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Manage External Storage');
        }));
    await Future.delayed(Duration(milliseconds: wait));
    bool permManageExternalStorage =
        await PermissionChecker.checkManageExternalStorage();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Notification');
        }));
    await Future.delayed(Duration(milliseconds: wait));
    bool permNotification = await PermissionChecker.checkNotification();

    Future.microtask(() => setState(() {
          updatePermissionsInfo('Check Permission Manage Calendar');
        }));
    await Future.delayed(Duration(milliseconds: wait));
    bool permCalendar = await PermissionChecker.checkCalendar();

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

    ///
    ///
    if (FileHandler.storagePath == null) {
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

    ///
    ///
    items.add(Center(
        child: ElevatedButton(
            onPressed: () {
              _permissionItems().then((_) {
                renderBody();
              });
            },
            child: const Text('Repeat Check Permissions'))));
    if (!await PermissionChecker.checkAll()) {
      items.add(Center(
          child: ElevatedButton(
              onPressed: () {
                PermissionChecker.requestAll().then((_) {
                  renderBody();
                });
              },
              child: const Text('Request Permissions'))));
    }
  }

  void renderBody() {
    widgetPermissions = ListView(children: [...items]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    bool id = ((ModalRoute.of(context)?.settings.arguments ?? 0) as int) > 0;
    if (PermissionChecker.permissionsChecked &&
        PermissionChecker.permissionsOk &&
        !id) {
      Future.delayed(const Duration(milliseconds: 200),
          () => AppWidgets.navigate(context, AppRoutes.liveTracking));
    }
    return AppWidgets.scaffold(context, body: widgetPermissions);
  }
}
