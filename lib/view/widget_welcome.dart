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

import 'package:chaostours/channel/notification_channel.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

///
import 'package:chaostours/conf/license.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/runtime_data.dart';
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/tracking.dart';
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
    if (await Permission.calendarFullAccess.isPermanentlyDenied) {
      await dialogPermissionRequest('Calendar Access');
    } else {
      await Permission.calendarFullAccess.request();
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
                  await Permission.ignoreBatteryOptimizations.isGranted) &&
              (permissionNotificationIsGranted =
                  await Permission.notification.isGranted)
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
      isTracking = await BackgroundChannel.isRunning();
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
              await Permission.ignoreBatteryOptimizations.isGranted) &&
              (permissionNotificationIsGranted =
                  await Permission.notification.isGranted) &&
               */
          (permissionManageExternalStorageIsGranted =
                  await Permission.manageExternalStorage.isGranted) &&
              (permissionCalendarIsGranted =
                  await Permission.calendarFullAccess.isGranted);
    } catch (e) {
      // ignore
    }

    try {
      isTracking = await BackgroundChannel.isRunning();
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
      (success) async {
        await Future.delayed(const Duration(seconds: 1));
        if (success) {
          preloadFinished = true;
          Future.delayed(const Duration(milliseconds: 200), () => render());
        }
      },
    );
  }

  void render() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> updatePermission() async {
    await checkAllPermissions();
    if (mounted) {
      Navigator.popAndPushNamed(context, AppRoutes.welcome.route, arguments: 1);
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
          title: const Text('Background GPS Tracking Status'),
          subtitle: const Text('Start / Stop'),
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
              updatePermission();
            },
          )));
    }

    if (isTracking) {
      trackingItems.add(Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
              onPressed: () {
                Navigator.popAndPushNamed(
                    context, AppRoutes.liveTracking.route);
              },
              child: const Text('Go Live Tracking...'))));
    }

    if (!permissionLocationIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Common foreground GPS Tracking.'),
          subtitle: const Text(
              'Needed for Maps and reverse Address Lookup from OpenStreetMap.com'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await requestLocation();
              updatePermission();
            },
          )));
    }
    if (!permissionLocationAlwaysIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Background GPS Tracking'),
          subtitle: const Text(
              'Needed to detect Move and Stop detection and its locations.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await requestLocation();
              updatePermission();
            },
          )));
    }

    if (!permissionIgnoreBatteryOptimizationsIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Ignore Battery optimization.'),
          subtitle: const Text(
              'Needed to prevent the Android system from app shutdown when running in background.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await requestBatteryOptimization();
              updatePermission();
            },
          )));
    }
    if (!permissionNotificationIsGranted) {
      permissionItemsRequired.add(ListTile(
          title: const Text('Show notifications.'),
          subtitle: const Text(
              'Needed to inform you about automatic alias creation or Moving/Standing Status changes.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await requestNotification();
              updatePermission();
            },
          )));
    }
    if (!permissionManageExternalStorageIsGranted) {
      permissionItemsOptional.add(ListTile(
          title: const Text('Access to external File system.'),
          subtitle: const Text('Needed to export or import the Database.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await requestExternalStorage();
              updatePermission();
            },
          )));
    }
    if (!permissionCalendarIsGranted) {
      permissionItemsOptional.add(ListTile(
          title: const Text('Access to your device calendar (if installed)'),
          subtitle: const Text(
              'You can track and share your stops with the device Google calendar.'),
          trailing: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await requestCalendar();
              updatePermission();
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
                    () => Navigator.popAndPushNamed(
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
                  ];
                })());
          },
        ));
  }

  ///
  /// preload recources
  Future<bool> preload() async {
    try {
      if (!(await Cache.licenseConsentChaosTours.load<bool>(false))) {
        bool consent = await chaosToursLicenseConsent();
        if (consent) {
          await Cache.licenseConsentChaosTours.save<bool>(true);
        } else {
          await Cache.licenseConsentChaosTours.save<bool>(false);
          await addPreloadMessage(
              const Text('App stopped due to rejected License consent.'));
          await addPreloadMessage(FloatingActionButton(
            child: const Text('Tap here to try again.'),
            onPressed: () {
              if (mounted) {
                Navigator.popAndPushNamed(context, AppRoutes.welcome.route);
              }
            },
          ));
        }
      }

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
                  title: 'Initial Alias',
                  description: 'Initial Alias created by System on first run.'
                      '\nFeel free to change it for your needs.')
              .insert();

          await addPreloadMessage(
              const Text('Execute first background tracking from foreground'));
          await Tracker().track();
        } catch (e) {
          await addPreloadMessage(const Text(
              'Create initial location alias failed. No GPS Permissions granted?'));
        }
      }

      if (!(await Permission.notification.isGranted) && mounted) {
        await AppWidgets.dialog(context: context, contents: [
          const Text('Chaos Tours requires\n'
              'Notification permission granted\n'
              'to be able to track GPS in background mode.\n'
              'Do you want to track GPS while this App is closed?')
        ], buttons: [
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () async {
              await requestNotification();
              if (await Permission.notification.isGranted) {
                Cache.appSettingBackgroundTrackingEnabled.save<bool>(true);
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
          )
        ]);
      }

      if (await Cache.appSettingBackgroundTrackingEnabled.load<bool>(false)) {
        // request gps always
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
      }

      if (!(await Cache.useOfOsmAddressLookupRequested.load<bool>(false)) &&
          mounted) {
        await AppWidgets.dialog(context: context, contents: [
          const Text('Do you want to use the GPS-to-Address Future?\n'
              'This future sends your GPS location to the free service of OpenStreetMap.com and receives an Address you can use.'),
          TextButton(
            child: const Text(
                'For more Informations please visit OpenStreetMap.com'),
            onPressed: () async {
              await launchUrl(Uri(
                scheme: 'https',
                host: 'openstreetmap.com',
              ));
            },
          )
        ], buttons: [
          TextButton(
            child: const Text('No'),
            onPressed: () async {
              await Cache.appSettingOsmLookupCondition
                  .save<OsmLookupConditions>(OsmLookupConditions.never);
              await Cache.licenseConsentRequestedOsm.save<bool>(false);
              await Cache.useOfOsmAddressLookupRequested.save<bool>(true);
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () async {
              await Cache.useOfOsmAddressLookupRequested.save<bool>(true);
              if (!(await Cache.licenseConsentRequestedOsm.load<bool>(false))) {
                if (await osmLicenseConsent()) {
                  await Cache.appSettingOsmLookupCondition
                      .save<OsmLookupConditions>(
                          OsmLookupConditions.onAutoCreateAlias);
                  await Cache.licenseConsentRequestedOsm.save<bool>(true);
                  await Cache.licenseConsentOsm.save<bool>(true);
                }
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
          )
        ]);
      }

      if (await Permission.notification.isGranted) {
        await NotificationChannel.initialize();
        if (await Permission.location.isGranted) {
          await BackgroundChannel.initialize();
        }
      }

      await loadWebSSLKey();

      var cache = Cache.appSettingBackgroundTrackingInterval;
      var dur = await cache
          .load<Duration>(AppUserSetting(cache).defaultValue as Duration);
      await addPreloadMessage(
          Text('Initialize background trackig with ${dur.inSeconds} sec.'));
      await BackgroundChannel.initialize();

      //
      //await BackgroundTracking.initialize();
      if (await Cache.appSettingBackgroundTrackingEnabled.load<bool>(true)) {
        await addPreloadMessage(const Text('Start background tracking'));
        await BackgroundChannel.start();
      } else {
        await addPreloadMessage(
            const Text('Background tracking not enabled, skip start tracking'));
      }

      // init and start app tickers
      await addPreloadMessage(const Text('Start foreground interval'));
      RuntimeData();

      await addPreloadMessage(const Text('Check Permissions...'));

      bool perm = await checkAllRequiredPermissions();
      await checkAllOptionalPermissions();
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
  static Future<void> loadWebSSLKey() async {
    Uint8List cachedKey =
        Uint8List.fromList((await Cache.webSSLKey.load<String>('')).codeUnits);

    if (cachedKey.isEmpty) {
      final uri = Uri.http('letsencrypt.org', '/certs/lets-encrypt-r3.pem');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        cachedKey = Uint8List.fromList(response.body.trim().codeUnits);
      }
    }

    if (cachedKey.isEmpty) {
      ByteData data =
          await PlatformAssetBundle().load('assets/lets-encrypt-r3.pem');
      cachedKey = data.buffer.asUint8List();
    }

    io.SecurityContext.defaultContext.setTrustedCertificatesBytes(cachedKey);

    await Cache.webSSLKey.save<String>(String.fromCharCodes(cachedKey));
  }

  Future<bool> chaosToursLicenseConsent() async {
    var licenseConsent = await Cache.licenseConsentChaosTours.load<bool>(false);
    var consentGiven = false;
    if (licenseConsent) {
      return true;
    }
    if (mounted) {
      await AppWidgets.dialog(context: context, contents: [
        TextButton(
          child: Text(chaosToursLicense),
          onPressed: () async {
            await launchUrl(
                Uri.parse('http://www.apache.org/licenses/LICENSE-2.0'));
          },
        )
      ], buttons: [
        TextButton(
          child: const Text('Decline'),
          onPressed: () {
            consentGiven = false;
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: const Text('Consent'),
          onPressed: () {
            consentGiven = true;
            Navigator.pop(context);
          },
        )
      ]);
    }
    return consentGiven;
  }

  Future<bool> osmLicenseConsent() async {
    var licenseConsent = await Cache.licenseConsentChaosTours.load<bool>(false);
    var consentGiven = false;
    if (licenseConsent) {
      return true;
    }
    if (mounted) {
      await AppWidgets.dialog(context: context, contents: [
        TextButton(
          child: Text(osmLicense),
          onPressed: () async {
            await launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'));
          },
        )
      ], buttons: [
        TextButton(
          child: const Text('Decline'),
          onPressed: () {
            consentGiven = false;
            Navigator.pop(context);
          },
        ),
        TextButton(
          child: const Text('Consent'),
          onPressed: () {
            consentGiven = true;
            Navigator.pop(context);
          },
        )
      ]);
    }
    return consentGiven;
  }
}
