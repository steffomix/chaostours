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
import 'package:chaostours/channel/tracking.dart';

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

  ///
  /// preload recources
  Future<void> preload() async {
    GPS? gps;
    Address? address;
    DataChannel channel = DataChannel();

    try {
      if (!(await Cache.licenseConsentChaosTours.load<bool>(false))) {
        bool consent = await chaosToursLicenseConsent();
        if (consent) {
          await Cache.licenseConsentChaosTours.save<bool>(true);
        } else {
          await Cache.licenseConsentChaosTours.save<bool>(false);
          sinkNext(const Text('App stopped due to rejected License consent.'));
          Future.delayed(
              const Duration(seconds: 2), () => SystemNavigator.pop());
        }
      }

      Logger.globalLogLevel = LogLevel.verbose;
      sinkNext(const Text('Start Initialization...'));

      //
      sinkNext(const Text('Open Database...'));
      // open database
      try {
        await DB.openDatabase(create: true);
      } catch (e) {
        sinkNext(Text('Error $e'));
        await Future.delayed(const Duration(seconds: 1), () {
          AppRoutes.navigate(context, AppRoutes.importExport, e);
        });

        return;
      }
      sinkNext(const Text('Database opened'));

      var count = await ModelAlias.count();
      if (count == 0) {
        sinkNext(const Text('Initalize user settings'));

        /// UserSettings initialize
        await AppUserSetting.resetAllToDefault();

        sinkNext(const Text('Request GPS permission'));
        if (mounted) {
          await AppWidgets.requestLocation(context);
        }

        try {
          if (!await Permission.location.isGranted) {
            if (mounted) {
              await AppWidgets.requestLocation(context);
            }
            if (!await Permission.location.isGranted) {
              if (mounted) {
                await AppWidgets.requestLocation(context);
              }
              sinkNext(const Text('This app is based on GPS location tracking. '
                  '\nTherefore you should at least grant some GPS location permissions.'));
            }
          }

          sinkNext(const Text('Lookup GPS'));
          gps = await GPS.gps();

          sinkNext(const Text('Create initial alias'));
          await ModelAlias(
                  gps: (gps),
                  lastVisited: DateTime.now(),
                  title: 'Initial Alias',
                  description: 'Initial Alias created by System on first run.'
                      '\nFeel free to change it for your needs.')
              .insert();

          sinkNext(
              const Text('Execute first background tracking from foreground'));
          await Tracker().track();
        } catch (e) {
          sinkNext(const Text(
              'Create initial location alias failed. No GPS Permissions granted?'));
        }
      }

      if (!(await Permission.notification.isGranted) && mounted) {
        await AppWidgets.dialog(context: context, contents: [
          const Text('Chaos Tours requires Notifications '
              'to be able to track GPS in background.')
        ], buttons: [
          TextButton(
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
      if (!(await Cache.requestBatteryOptimization.load<bool>(false))) {
        if (!(await Permission.ignoreBatteryOptimizations.isGranted) &&
            mounted) {
          await AppWidgets.dialog(context: context, contents: [
            const Text('Disable Battery Optimization?\n\n'
                'To make this App run in background it is strongly recommended to disable Battery optimization.\n'
                'Otherwise the System will put the App to sleep after some minutes.'),
            TextButton(
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
            TextButton(
              child: const Text('No'),
              onPressed: () async {
                await Cache.requestBatteryOptimization.save<bool>(true);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () async {
                await Permission.ignoreBatteryOptimizations.request();
                await Cache.requestBatteryOptimization.save<bool>(true);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            )
          ]);
        }
      }

      if (!(await Cache.requestOsmAddressLookup.load<bool>(false)) && mounted) {
        await AppWidgets.dialog(context: context, contents: [
          const Text('Enable GPS-to-Address?\n\n'
              'This future sends your GPS location to OpenStreetMap.com and receives an Address you can use.'),
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
              await Cache.requestLicenseConsentOsm.save<bool>(false);
              await Cache.requestOsmAddressLookup.save<bool>(true);
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () async {
              await Cache.requestOsmAddressLookup.save<bool>(true);
              if (!(await Cache.requestLicenseConsentOsm.load<bool>(false))) {
                if (await osmLicenseConsent()) {
                  await Cache.appSettingOsmLookupCondition
                      .save<OsmLookupConditions>(
                          OsmLookupConditions.onAutoCreateAlias);
                  await Cache.requestLicenseConsentOsm.save<bool>(true);
                  await Cache.licenseConsentOsm.save<bool>(true);
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
          sinkNext(
              Text('Initialize background trackig with ${dur.inSeconds} sec.'));
          await BackgroundChannel.initialize();
        }
      }

      //
      //await BackgroundTracking.initialize();
      if (await Cache.appSettingBackgroundTrackingEnabled.load<bool>(true)) {
        sinkNext(const Text('Start background tracking'));
        await BackgroundChannel.start();
      } else {
        sinkNext(
            const Text('Background tracking not enabled, skip start tracking'));
      }

      sinkNext(const Text('Load Web SSL key.'));
      await loadWebSSLKey();

      sinkNext(const Text('Check Permissions...'));

      bool perm = await checkAllRequiredPermissions();

      if (gps == null && (await Permission.location.isGranted)) {
        sinkNext(const Text('Lookup GPS'));
        gps = await GPS.gps();
      }
      if (gps != null &&
          (await OsmLookupConditions.onStatusChanged.allowLookup()) &&
          address == null) {
        sinkNext(const Text('Lookup Address'));
        address = await Address(gps)
            .lookup(OsmLookupConditions.onStatusChanged, saveToCache: true);
        channel.address = address?.address ?? '';
        channel.fullAddress = address?.addressDetails ?? '';
      }

      sinkNext(const Text('Start App...'));
      if (perm) {
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
