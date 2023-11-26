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

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io' as io;
import 'package:flutter/services.dart';

///
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/database.dart';
import 'package:chaostours/runtime_data.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/tracking.dart' as tracking;
//import 'package:chaostours/logger.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  static final Logger logger = Logger.logger<Welcome>();

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

  Future<void> requestLocation() async {
    var service = await Permission.location.serviceStatus;
    if (service.isDisabled) {
      if (mounted) {
        await AppWidgets.dialog(context: context, contents: [
          const Text(
              'Your GPS Service seems to be disabled. Please enable your GPS Service first.')
        ], buttons: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {},
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              await AppSettings.openAppSettings(type: AppSettingsType.location);
              if (mounted) {
                Navigator.pop(context);
              }
            },
          )
        ]);
      }
    }
    await Permission.location.request();
  }

  Future<void> requestLocationAlways() async {
    var status = await Permission.locationAlways.request();
    if ((status.isDenied || status.isPermanentlyDenied) && mounted) {
      await AppWidgets.dialog(context: context, contents: [
        const Text(
            'Oops, something went wrong on request access for GPS!\nPlease grant access to "GPS Always" in your App Settings directly.')
      ], buttons: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {},
        ),
        TextButton(
          child: const Text('OK'),
          onPressed: () async {
            await AppSettings.openAppSettings(type: AppSettingsType.settings);
            await Permission.locationAlways.request();
            if (mounted) {
              Navigator.pop(context);
            }
          },
        )
      ]);
    }
  }

  Future<void> requestBatteryOptimization() async {
    if (await Permission.ignoreBatteryOptimizations.isPermanentlyDenied) {
      await AppSettings.openAppSettings(
          type: AppSettingsType.batteryOptimization);
    } else {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> requestStorage() async {
    if (await Permission.storage.isPermanentlyDenied) {
      await AppSettings.openAppSettings(type: AppSettingsType.internalStorage);
    } else {
      await Permission.storage.request();
    }
  }

  Future<void> requestExternalStorage() async {
    if (await Permission.manageExternalStorage.isPermanentlyDenied) {
      await dialogPermissionRequest('Manage external Storage');
    } else {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> requestNotification() async {
    if (await Permission.notification.isPermanentlyDenied) {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } else {
      await Permission.notification.request();
    }
  }

  Future<void> requestCalendar() async {
    if (await Permission.calendar.isPermanentlyDenied) {
      await dialogPermissionRequest('Calendar Access');
    } else {
      await Permission.calendar.request();
    }
  }

  Future<void> requestAllPermissions() async {
    await requestLocation();
    await requestLocationAlways();
    await requestBatteryOptimization();
    await requestStorage();
    await requestExternalStorage();
    await requestNotification();
    await requestCalendar();
  }

  Future<void> dialogPermissionRequest(String permission) async {
    await AppWidgets.dialog(context: context, contents: [
      Text(
          'You have permanently denied permission "$permission", so that it is impossible to request this permission from within the app. '
          'However, you can still access the general app settings page from here. ')
    ], buttons: [
      TextButton(
        child: const Text('Cancel'),
        onPressed: () async {
          await AppSettings.openAppSettings(type: AppSettingsType.settings);
          if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
      TextButton(
        child: const Text('App Settings'),
        onPressed: () {},
      )
    ]);
  }

  Future<bool> checkAllRequiredPermissions() async {
    bool granted = false;
    try {
      granted = (permissionLocationIsGranted =
                  await Permission.location.isGranted) &&
              (permissionLocationAlwaysIsGranted =
                  await Permission.locationAlways.isGranted) &&
              (permissionIgnoreBatteryOptimizationsIsGranted =
                  await Permission.ignoreBatteryOptimizations.isGranted)
          /* &&
          (permissionManageExternalStorageIsGranted =
              await Permission.manageExternalStorage.isGranted) &&
          (permissionNotificationIsGranted =
              await Permission.notification.isGranted) &&
          (permissionCalendarIsGranted = await Permission.calendar.isGranted)*/
          ;
    } catch (e) {
      // ignore
    }

    try {
      isTracking = await BackgroundTracking.isTracking();
    } catch (e) {
      isTracking = false;
    }
    return granted && isTracking;
  }

  Future<bool> checkAllOptionalPermissions() async {
    bool granted = false;
    try {
      granted = /* (permissionLocationIsGranted =
              await Permission.location.isGranted) &&
          (permissionLocationAlwaysIsGranted =
              await Permission.locationAlways.isGranted) &&
          (permissionIgnoreBatteryOptimizationsIsGranted =
              await Permission.ignoreBatteryOptimizations.isGranted) && */
          (permissionManageExternalStorageIsGranted =
                  await Permission.manageExternalStorage.isGranted) &&
              (permissionNotificationIsGranted =
                  await Permission.notification.isGranted) &&
              (permissionCalendarIsGranted =
                  await Permission.calendar.isGranted);
    } catch (e) {
      // ignore
    }

    try {
      isTracking = await BackgroundTracking.isTracking();
    } catch (e) {
      isTracking = false;
    }
    return granted && isTracking;
  }

  Future<bool> checkAllPermissions() async {
    return await checkAllRequiredPermissions() &&
        await checkAllOptionalPermissions();
  }

  @override
  void initState() {
    super.initState();
    if (preloadFinished) {
      return;
    }
    preload().then(
      (_) async {
        await Future.delayed(const Duration(seconds: 1));
        preloadFinished = true;
        Future.delayed(const Duration(milliseconds: 200), () => render());
      },
    );
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
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
              requestLocation().then(
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
              requestLocation().then(
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
              requestBatteryOptimization().then(
                (_) {
                  setState(() {});
                },
              );
            },
          )));
    }
    if (!permissionNotificationIsGranted) {
      permissionItemsOptional.add(ListTile(
          title: const Text('Anzeige von App-Meldungen.'),
          subtitle: const Text(
              'Wird benötigt wenn sie über Statuswechsel informiert werden wollen.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              requestLocation().then(
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
              requestExternalStorage().then(
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
              requestCalendar().then(
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

  static bool preloadFinished = false;
  static List<Widget> preloadMessages = [];
  Future<void> addPreloadMessage(Widget message) async {
    preloadMessages.add(message);
    render();
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    if (!preloadFinished) {
      return AppWidgets.scaffold(
        context,
        title: 'Initialize Chaos Tours...',
        body: ListView(
          children: [...preloadMessages],
        ),
      );
    }
    return AppWidgets.scaffold(context,
        title: 'Chaos Tours Permission check',
        body: FutureBuilder<bool>(
          future: checkAllPermissions(),
          builder: (context, snapshot) {
            Widget? loading = AppWidgets.checkSnapshot(context, snapshot);
            if (loading == null) {
              final permissionsOk = snapshot.data!;
              final bool stop =
                  ModalRoute.of(context)?.settings.arguments != null;
              if (permissionsOk && !stop) {
                Future.delayed(
                    const Duration(milliseconds: 500),
                    () => Navigator.pushNamed(
                        context, AppRoutes.liveTracking.route));
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

  ///
  /// preload recources
  Future<bool> preload() async {
    try {
      Logger.globalLogLevel = LogLevel.verbose;
      await addPreloadMessage(const Text('Start Initialization...'));

      //
      await addPreloadMessage(const Text('Open Database...'));
      // open database
      await DB.openDatabase(create: true);
      await addPreloadMessage(const Text('Database opened'));

      var count = await ModelAlias.count();
      if (count == 0) {
        await addPreloadMessage(const Text('Initalize user settings'));

        /// UserSettings initialize
        await AppUserSetting.resetAllToDefault();

        await addPreloadMessage(const Text('Request GPS permission'));
        await requestLocation();

        try {
          if (!await Permission.location.isGranted) {
            await requestLocation();
            if (!await Permission.location.isGranted) {
              await requestLocation();
              await addPreloadMessage(const Text(
                  'This app is based on GPS location tracking. '
                  '\nTherefore you should at least grant some GPS location permissions.'));
            }
          }

          await addPreloadMessage(const Text('Lookup GPS'));
          GPS gps = await GPS.gps();
          await addPreloadMessage(const Text('Create initial alias'));
          await ModelAlias(
                  gps: gps,
                  lastVisited: DateTime.now(),
                  title: (await Address(gps).lookupAddress()).toString(),
                  description: 'Initial Alias created by System on first run.'
                      '\nFeel free to change it for your needs.')
              .insert();

          if (!(await Permission.locationAlways.isGranted) && mounted) {
            await AppWidgets.dialog(context: context, contents: [
              const Text(
                  'For Background GPS Tracking the app need GPS permission "Always". '
                  'Please tap OK to get to the permission request.')
            ], buttons: [
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  await requestLocationAlways();
                  if (await Permission.locationAlways.isGranted && mounted) {
                    Navigator.pop(context);
                  }
                },
              )
            ]);
          }
          await requestLocationAlways();

          await addPreloadMessage(
              const Text('Execute first background tracking from foreground'));
          tracking.track(gps);
        } catch (e) {
          await addPreloadMessage(const Text(
              'Create initial location alias failed. No GPS Permissions granted?'));
        }
      }

      //
      await addPreloadMessage(const Text('Load Web SSL key'));
      await webKey();

      //
      await BackgroundTracking.initialize();
      if (await Cache.appSettingBackgroundTrackingEnabled.load<bool>(true)) {
        await addPreloadMessage(const Text('Start background tracking'));
        await BackgroundTracking.startTracking();
      }

      // init and start app tickers
      await addPreloadMessage(const Text('Start foreground interval'));
      RuntimeData();

      await addPreloadMessage(const Text('Check Permissions...'));

      bool perm = await checkAllRequiredPermissions();
      if (perm) {
        preloadFinished = true;
        if (mounted) {
          Navigator.popAndPushNamed(context, AppRoutes.liveTracking.route);
        }
      }
    } catch (e, stk) {
      await addPreloadMessage(ListTile(
          title: Text('Initialization Error $e'),
          subtitle: Text(stk.toString())));
      logger.fatal('Initialization Error $e', stk);
      return false;
    }

    // init and start app tickers
    RuntimeData();

    logger.important('Preload sequence finished without errors');
    return true;
  }

  ///
  /// load ssh key for https connections
  /// add cert for https requests you can download here:
  /// https://letsencrypt.org/certs/lets-encrypt-r3.pem
  static Future<void> webKey() async {
    ByteData data =
        await PlatformAssetBundle().load('assets/lets-encrypt-r3.pem');
    io.SecurityContext.defaultContext
        .setTrustedCertificatesBytes(data.buffer.asUint8List());
    logger.log('SSL Key loaded');
  }
}
