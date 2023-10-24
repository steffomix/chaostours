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

import 'package:chaostours/app_loader.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

///
import 'package:chaostours/view/app_widgets.dart';
//import 'package:chaostours/logger.dart';
import 'package:chaostours/tracking.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  //static final Logger logger = Logger.logger<AppInit>();

  bool preloadSuccess = false;

  List<Widget> permissionItemsRequired = [];
  List<Widget> permissionItemsOptional = [];

  List<Widget> trackingItems = [];

  bool permissionLocationIsGranted = false;
  bool permissionLocationAlwaysIsGranted = false;
  bool permissionIgnoreBatteryOptimizationsIsGranted = false;
  bool permissionStorageIsGrantd = false;
  bool permissionManageExternalStorageIsGranted = false;
  bool permissionNotificationIsGranted = false;
  bool permissionCalendarIsGranted = false;

  //
  bool isTracking = false;

  //
  Widget divider = AppWidgets.divider();
  Widget empty = AppWidgets.empty;

  Future<void> requestAllPermissions() async {
    await Permission.location.request();
    await Permission.locationAlways.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    await Permission.notification.request();
    await Permission.calendar.request();
  }

  Future<bool> checkAllPermissions() async {
    bool granted = false;
    try {
      granted = (permissionLocationIsGranted =
              await Permission.location.isGranted) &&
          (permissionLocationAlwaysIsGranted =
              await Permission.locationAlways.isGranted) &&
          (permissionIgnoreBatteryOptimizationsIsGranted =
              await Permission.ignoreBatteryOptimizations.isGranted) &&
          (permissionManageExternalStorageIsGranted =
              await Permission.manageExternalStorage.isGranted) &&
          (permissionNotificationIsGranted =
              await Permission.notification.isGranted) &&
          (permissionCalendarIsGranted = await Permission.calendar.isGranted);
    } catch (e) {
      // ignore
    }

    preloadSuccess = await AppLoader.preload;
    try {
      isTracking = await BackgroundTracking.isTracking();
    } catch (e) {
      isTracking = false;
    }
    return granted && isTracking;
  }

  @override
  void initState() {
    super.initState();
  }

  void renderItems() {
    permissionItemsOptional.clear();
    permissionItemsRequired.clear();
    trackingItems.clear();

    if (permissionLocationAlwaysIsGranted) {
      trackingItems.add(ListTile(
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
                setState(() {});
              } else {
                await BackgroundTracking.initialize();
                await BackgroundTracking.startTracking();
                setState(() {});
              }
            },
          )));
    }

    if (isTracking) {
      trackingItems.add(Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.liveTracking.route);
              },
              child: const Text('Go Live Tracking...'))));
    }

    if (!permissionLocationIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Einfache (Vordergrund) GPS Ortung.'),
          subtitle: const Text(
              'Wird für für die Karte und Sortierung der Orte benötigt.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Permission.location.request().then(
                (_) {
                  setState(() {});
                },
              );
            },
          )));
    }
    if (!permissionLocationAlwaysIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Hintergrund GPS Ortung.'),
          subtitle: const Text('Das Herz dieser App. Wird für die Ortung, '
              'Status Halten und Status Fahren benötigt.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Permission.locationAlways.request().then(
                (_) {
                  setState(() {});
                },
              );
            },
          )));
    }

    if (!permissionIgnoreBatteryOptimizationsIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Ignorieren der Batterieoptimierung.'),
          subtitle: const Text(
              'Sorgt dafür dass die App nicht vom Android-System abgeschaltet wird.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Permission.ignoreBatteryOptimizations.request().then(
                (_) {
                  setState(() {});
                },
              );
            },
          )));
    }
    if (!permissionNotificationIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Anzeige von App-Meldungen.'),
          subtitle: const Text(
              'Wird benötigt wenn sie über Statuswechsel informiert werden wollen.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Permission.notification.request().then(
                (_) {
                  setState(() {});
                },
              );
            },
          )));
    }
    if (!permissionManageExternalStorageIsGranted) {
      permissionItemsOptional.add(ListTile(
          title: const Text('Zugriff auf App-Externes Dateisystem.'),
          subtitle: const Text(
              'Wird benötigt wenn sie auf ihre Daten von außerhalb diese App zugreifen wollen. '
              'Schauen sie im Hauptmenü unter "Speicherorte" für weitere Optionen.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Permission.manageExternalStorage.request().then(
                (_) {
                  setState(() {});
                },
              );
            },
          )));
    }
    if (!permissionCalendarIsGranted) {
      permissionItemsOptional.add(ListTile(
          title: const Text('Zugriff auf Geräte-Kalender.'),
          subtitle: const Text(
              'Wird benötigt, wenn sie Statusereignisse in ihren Kalender eintragen lassen wollen.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Permission.calendar.request().then(
                (_) {
                  setState(() {});
                },
              );
            },
          )));
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget header(String text) {
    return Center(
        child: Text(text, style: const TextStyle(fontSize: 20, height: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: FutureBuilder<bool>(
          future: checkAllPermissions(),
          builder: (context, snapshot) {
            Widget? loading = AppWidgets.checkSnapshot(snapshot);
            if (loading == null) {
              final permissionsOk = snapshot.data!;
              if (!preloadSuccess) {
                Future.delayed(const Duration(seconds: 2),
                    () => Navigator.pushNamed(context, AppRoutes.logger.route));
                return AppWidgets.loading('Initialization Failure...');
              } else {
                if (permissionsOk) {
                  Future.delayed(
                      const Duration(milliseconds: 500),
                      () => Navigator.pushNamed(
                          context, AppRoutes.liveTracking.route));
                }
              }
            }

            return loading ??
                ListView(children: (() {
                  renderItems();
                  return [
                    header('ChaosTours main Settings'),
                    divider,
                    ...permissionLocationAlwaysIsGranted
                        ? [divider, header('Background Tracking status')]
                        : [divider],
                    ...trackingItems,
                    ...[divider, divider],
                    permissionItemsRequired.isNotEmpty
                        ? header('Required Permissions')
                        : empty,
                    ...permissionItemsRequired,
                    permissionItemsRequired.isEmpty
                        ? header('All required Permissions granted')
                        : empty,
                    divider,
                    permissionItemsOptional.isNotEmpty
                        ? header('Optional Permissions')
                        : empty,
                    ...permissionItemsOptional,
                    permissionItemsOptional.isEmpty
                        ? header('All optional Permissions granted')
                        : empty,
                    divider,
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: ElevatedButton(
                          child: const Text('Request all Permissions anyway'),
                          onPressed: () {
                            requestAllPermissions();
                          },
                        ))
                  ];
                })());
          },
        ));
  }
}
