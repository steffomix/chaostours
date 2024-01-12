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

import 'dart:async';
import 'dart:io';
import 'package:chaostours/location.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:http/http.dart' as http;
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

///
import 'package:chaostours/channel/data_channel.dart';
import 'package:chaostours/channel/notification_channel.dart';
import 'package:chaostours/conf/license.dart';
import 'package:chaostours/address.dart';
import 'package:chaostours/conf/app_routes.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/view/app_widgets.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  static final Logger logger = Logger.logger<Welcome>();

  final List<Widget> bootLog = [];

  @override
  void initState() {
    Future.delayed(const Duration(seconds: 2), preload);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Booting Chaos Tours...')),
        body: StreamBuilder(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                bootLog.add(snapshot.data!);
              }
              return ListView(children: [...bootLog]);
            }));
  }

  Future<bool> checkAllRequiredPermissions() async {
    return (await Permission.location.isGranted) &&
        (await Permission.notification.isGranted);
  }

  void sinkNext(Widget widget) {
    sink.add(widget);
  }

  final _stream = StreamController<Widget>();
  Sink get sink => _stream.sink;
  Stream get stream => _stream.stream;

  GPS? gps;
  Address? address;
  DataChannel channel = DataChannel();
  bool isFirstRun = false;

  ///
  /// preload recources
  Future<void> preload() async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      // check chaosTours license
      if (!(await Cache.chaosToursLicenseAccepted.load<bool>(false))) {
        bool consent = await chaosToursLicenseConsent();
        if (consent) {
          await Cache.chaosToursLicenseAccepted.save<bool>(true);
        } else {
          await Cache.chaosToursLicenseAccepted.save<bool>(false);
          sinkNext(const Text('App stopped due to rejected License consent.'));
          Future.delayed(
              const Duration(seconds: 2), () => SystemNavigator.pop());
        }
      }

      Logger.globalLogLevel = LogLevel.verbose;
      sinkNext(const Text('Start Initialization...'));

      // open database
      sinkNext(const Text('Open Database...'));
      try {
        await DB.openDatabase(create: true);
      } catch (e, stk) {
        sinkNext(Text('Error $e'));
        if (!mounted) {
          exit(1);
        }
        await AppWidgets.dialog(
            context: context,
            isDismissible: false,
            title: const Text('Database Error'),
            contents: [
              Text(
                  'Open Database from ${await DB.getDBFullPath()} caused an Error:'),
              Text('\n $e'),
              Text('\n$stk')
            ],
            buttons: [
              FilledButton(
                child: const Text('Manage Database'),
                onPressed: () {
                  AppRoutes.navigate(context, AppRoutes.importExport, e);
                  Navigator.pop(context);
                },
              )
            ]);
        sinkNext(Text('Database Error $e. Start ChaosTours failed'));
        return;
      }
      sinkNext(const Text('Database opened'));

      sinkNext(const Text('Lookup GPS'));
      await Permission.location.request();
      if (await Permission.location.isPermanentlyDenied) {
        if (!mounted) {
          exit(1);
        }
        if (mounted) {
          await AppWidgets.requestLocation(context);
        }
      }
      await Permission.location.request();
      if (await Permission.location.isDenied) {
        exit(1);
      }
      gps = await GPS.gps();

      if (!(await Cache.cacheInitialized.load<bool>(false))) {
        isFirstRun = true;
        sinkNext(const Text('Initalize app setting defaults.'));
        await AppUserSetting.resetAllToDefault();
        await Cache.cacheInitialized.save<bool>(true);
      }

      if (!(await Permission.notification.isGranted) && mounted) {
        await AppWidgets.dialog(context: context, contents: [
          const Text('Chaos Tours requires Notifications '
              'to be able to track GPS while app is closed.')
        ], buttons: [
          FilledButton(
            child: const Text('OK'),
            onPressed: () async {
              await Permission.notification.request();
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

      if (!(await Cache.batteryOptimizationRequested.load<bool>(false))) {
        if (!(await Permission.ignoreBatteryOptimizations.isGranted) &&
            mounted) {
          await AppWidgets.dialog(context: context, contents: [
            const Text('Disable Battery Optimization?\n\n'
                'To make this App run in background it is strongly recommended to disable Battery optimization.\n'
                'Otherwise the System will put the App to sleep after some minutes.'),
            FilledButton(
              child: const Text(
                  'For more Informations please https://developer.android.com'),
              onPressed: () async {
                await launchUrl(Uri(
                    scheme: 'https',
                    host: 'developer.android.com',
                    pathSegments: [
                      'training',
                      'monitoring-device-state',
                      'doze-standby'
                    ]));
              },
            )
          ], buttons: [
            FilledButton(
              child: const Text('No'),
              onPressed: () async {
                await Cache.batteryOptimizationRequested.save<bool>(true);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            FilledButton(
              child: const Text('Yes'),
              onPressed: () async {
                await Permission.ignoreBatteryOptimizations.request();
                await Cache.batteryOptimizationRequested.save<bool>(true);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            )
          ]);
        }
      }

      sinkNext(const Text('Initialize SSL key for end-to-end encryption'));
      await loadWebSSLKey();

      if (!(await Cache.osmLicenseRequested.load<bool>(false)) && mounted) {
        await AppWidgets.dialog(
            context: context,
            title: const Text('Address Lookup'),
            contents: [
              const Text('Enable GPS-to-Address service?\n\n'
                  'This future sends your GPS location over an end-to-end encrypted connection to OpenStreetMap.com and receives an Address you can use.'),
              const Text(
                  'The service is cost free with a maximum of one request per second.'),
              FilledButton(
                child: const Text(
                    'For more Informations please visit OpenStreetMap.com'),
                onPressed: () async {
                  await launchUrl(Uri(
                    scheme: 'https',
                    host: 'openstreetmap.com',
                  ));
                },
              )
            ],
            buttons: [
              FilledButton(
                child: const Text('No'),
                onPressed: () async {
                  await Cache.appSettingOsmLookupCondition
                      .save<OsmLookupConditions>(OsmLookupConditions.never);
                  await Cache.osmLicenseRequested.save<bool>(true);
                  await Cache.osmLicenseAccepted.save<bool>(false);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              FilledButton(
                child: const Text('Yes'),
                onPressed: () async {
                  await Cache.osmLicenseRequested.save<bool>(true);
                  if (!(await Cache.osmLicenseAccepted.load<bool>(false))) {
                    if (await osmLicenseConsent()) {
                      await Cache.appSettingOsmLookupCondition
                          .save<OsmLookupConditions>(
                              OsmLookupConditions.onStatusChanged);
                      await Cache.osmLicenseAccepted.save<bool>(true);
                      sinkNext(const Text('Lookup Address...'));
                      address = await Address(gps ?? await GPS.gps()).lookup(
                          OsmLookupConditions.onUserRequest,
                          saveToCache: true);
                      channel.address = address?.address ?? '';
                      channel.fullAddress = address?.addressDetails ?? '';
                      sinkNext(Text(channel.fullAddress));
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
        sinkNext(const Text('Initialize Notifications'));
        await NotificationChannel.initialize();
        if (await Permission.location.isGranted) {
          var cache = Cache.appSettingBackgroundTrackingInterval;
          var dur = await cache
              .load<Duration>(AppUserSetting(cache).defaultValue as Duration);
          sinkNext(Text(
              'Initialize background trackig with ${dur.inSeconds} sec. interval'));
          await BackgroundChannel.initialize();
        }
      }

      //
      if (await Cache.appSettingBackgroundTrackingEnabled.load<bool>(true)) {
        sinkNext(const Text('Start background tracking'));
        await BackgroundChannel.start();
      } else {
        sinkNext(
            const Text('Background tracking not enabled, skip start tracking'));
      }

      if (!(await Cache.useOfCalendarRequested.load<bool>(false)) && mounted) {
        sinkNext(const Text('Request use of device calendar'));
        await AppWidgets.dialog(
            context: context,
            title: const Text('Device Calendar'),
            contents: [
              const Text(
                  'Write trackpoints to your personal device calendar (if installed)?'),
              const Text(
                  'Use your personal device calendar together with Chaos Tours, as aditional database or to share your well beings with your friends and familiy.\n'
                  'You will have very detailed options about the written content for each location group.'),
              FilledButton(
                  onPressed: () {
                    launchUrl(Uri.parse('https://calendar.google.com'));
                  },
                  child: const Text('For more information open\n'
                      'https://calendar.google.com'))
            ],
            buttons: [
              FilledButton(
                  onPressed: () async {
                    await Cache.appSettingPublishToCalendar.save<bool>(false);
                    await Cache.useOfCalendarRequested.save<bool>(true);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('No')),
              FilledButton(
                  onPressed: () async {
                    await Cache.appSettingPublishToCalendar.save<bool>(true);
                    await Cache.useOfCalendarRequested.save<bool>(true);
                    if (mounted) {
                      try {
                        await Permission.calendar.request();
                      } catch (e) {
                        //
                      }
                      await Permission.calendarFullAccess.request();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Yes')),
            ]);
      }

      bool osm = await OsmLookupConditions.onUserRequest.allowLookup();
      if (isFirstRun && mounted) {
        await AppWidgets.dialog(
            context: context,
            title: const Text('Install Data'),
            contents: [
              const Text(
                  'Install some basic data so that everything doesn\'t look so empty?'),
              Text('This is \n- a Location Alias ${osm ? 'with address' : ''}\n'
                  '- a user named "user 1" \n- a task named "task 1"'
                  '- a trackpoint with "user 1", "task 1" and a note "Welcome to Chaos Tours"'),
              const Text('You can of course edit everything every time.')
            ],
            buttons: [
              FilledButton(
                child: const Text('No'),
                onPressed: () async {
                  Navigator.pop(context);
                },
              ),
              FilledButton(
                child: const Text('Yes'),
                onPressed: () async {
                  await installData();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              )
            ]);
      }

      sinkNext(const Text('Start App...'));
      if (await checkAllRequiredPermissions()) {
        if (mounted) {
          Navigator.popAndPushNamed(context, AppRoutes.liveTracking.route);
        }
      } else if (mounted) {
        Navigator.popAndPushNamed(context, AppRoutes.permissions.route);
      }
    } catch (e, stk) {
      sinkNext(ListTile(
          title: Text('Initialization Error $e'),
          subtitle: Text(stk.toString())));
      logger.fatal('Initialization Error $e', stk);
    }

    logger.important('Preload sequence finished without errors');
  }

  Future<void> installData() async {
    gps ??= await GPS.gps();
    await ModelAlias(
            gps: gps!,
            title: 'First Alias',
            lastVisited: DateTime.now(),
            privacy: AliasPrivacy.privat)
        .insert();
    await ModelUser(title: 'User 1').insert();
    await ModelTask(title: 'Task 1').insert();

    await Cache.backgroundSharedAliasList.save<List<SharedTrackpointAlias>>([
      SharedTrackpointAlias(
          id: 1, notes: 'We was the nearby location most times.')
    ]);

    await Cache.backgroundSharedUserList.save<List<SharedTrackpointUser>>(
        [SharedTrackpointUser(id: 1, notes: 'User 1 was here.')]);

    await Cache.backgroundSharedTaskList.save<List<SharedTrackpointTask>>(
        [SharedTrackpointTask(id: 1, notes: 'Did some hard work.')]);

    await Cache.backgroundTrackPointNotes
        .save<String>('What a great location today!');

    Location location = await Location.location(gps!);
    location.address = address;

    await location.executeStatusMoving();
  }

  ///
  /// load ssh key for https connections
  /// add cert for https requests you can download here:
  /// https://letsencrypt.org/certs/lets-encrypt-r3.pem
  Future<void> loadWebSSLKey() async {
    Uint8List cachedKey =
        Uint8List.fromList((await Cache.webSSLKey.load<String>('')).codeUnits);

    if (cachedKey.isEmpty) {
      sinkNext(const Text(
          'Load SSL key from letsencrypt.org/certs/lets-encrypt-r3.pem'));
      final uri = Uri.http('letsencrypt.org', '/certs/lets-encrypt-r3.pem');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        cachedKey = Uint8List.fromList(response.body.trim().codeUnits);
      }
    }

    if (cachedKey.isEmpty) {
      sinkNext(const Text(
          'Load SSL key failed. Fallback to buil-in key. Please make sure you have a working internet connection.'));
      ByteData data =
          await PlatformAssetBundle().load('assets/lets-encrypt-r3.pem');
      cachedKey = data.buffer.asUint8List();
    }

    io.SecurityContext.defaultContext.setTrustedCertificatesBytes(cachedKey);

    await Cache.webSSLKey.save<String>(String.fromCharCodes(cachedKey));
  }

  Future<bool> chaosToursLicenseConsent() async {
    var licenseConsent =
        await Cache.chaosToursLicenseAccepted.load<bool>(false);
    var consentGiven = false;
    if (licenseConsent) {
      return true;
    }
    if (mounted) {
      await AppWidgets.dialog(context: context, contents: [
        FilledButton(
          child: Text(chaosToursLicense),
          onPressed: () async {
            await launchUrl(
                Uri.parse('http://www.apache.org/licenses/LICENSE-2.0'));
          },
        )
      ], buttons: [
        FilledButton(
          child: const Text('Decline'),
          onPressed: () {
            consentGiven = false;
            Navigator.pop(context);
          },
        ),
        FilledButton(
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
    var licenseConsent =
        await Cache.chaosToursLicenseAccepted.load<bool>(false);
    var consentGiven = false;
    if (licenseConsent) {
      return true;
    }
    if (mounted) {
      await AppWidgets.dialog(context: context, contents: [
        FilledButton(
          child: Text(osmLicense),
          onPressed: () async {
            await launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'));
          },
        )
      ], buttons: [
        FilledButton(
          child: const Text('Decline'),
          onPressed: () {
            consentGiven = false;
            Navigator.pop(context);
          },
        ),
        FilledButton(
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
