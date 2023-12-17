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

// ignore: depend_on_referenced_packages
import 'package:path_provider_android/path_provider_android.dart';
import 'dart:io';
import 'dart:ui';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

///
import 'package:chaostours/database/database.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/channel/notification_channel.dart';
import 'package:chaostours/tracking.dart';

enum BackgroundChannelCommand {
  startService,
  stopService,
  gotoForeground,
  gotoBackground,
  onUpdate,
  notify,
  ;

  @override
  String toString() => name;
}

class BackgroundChannel {
  static final Logger logger = Logger.logger<BackgroundChannel>();

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    if (Platform.isAndroid) {
      //PathProviderAndroid.registerWith();
    } else if (Platform.isIOS) {
      //PathProviderIOS.registerWith();
    }
    bool running = true;
    service.on(BackgroundChannelCommand.stopService.toString()).listen((event) {
      running = false;
      service.stopSelf();
    });
    await DB.openDatabase();
    int tick = 0;
    try {
      const Cache cache = Cache.appSettingBackgroundTrackingInterval;
      while (running) {
        try {
          Tracker().track();
          tick++;
          service.invoke(
              BackgroundChannelCommand.notify.toString(), {'tick': tick});
        } catch (e, stk) {
          logger.error('background tracking: $e', stk);
        }
        try {
          await Future.delayed(await cache
              .load<Duration>(AppUserSetting(cache).defaultValue as Duration));
        } catch (e) {
          logger.warn('Background interval delay failed. Fallback to default');
          Future.delayed(AppUserSetting(cache).defaultValue as Duration);
        }
      }
    } catch (e, stk) {
      logger.fatal('Background task crashed: $e', stk);
    }
  }

  static Future<void> start() async {
    if (!(await isRunning())) {
      FlutterBackgroundService().startService();
    }
  }

  static Future<void> stop() async {
    if (await isRunning()) {
      FlutterBackgroundService()
          .invoke(BackgroundChannelCommand.stopService.toString());
    }
  }

  static Future<bool> isRunning() async =>
      FlutterBackgroundService().isRunning();

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: NotificationChannel.backgroundNotificationId,
        initialNotificationTitle:
            NotificationChannel.backgroundNotificationTitle,
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId:
            NotificationChannel.foregroundServiceNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: false,

        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
  }
}
