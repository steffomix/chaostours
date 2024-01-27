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

// required for sqflite?
// ignore: depend_on_referenced_packages
// import 'package:path_provider_android/path_provider_android.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import 'dart:io';
import 'dart:ui';
import 'package:chaostours/database/type_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

///
import 'package:chaostours/logger.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/database/database.dart';
import 'package:chaostours/channel/notification_channel.dart';
import 'package:chaostours/util.dart' as util;

enum BackgroundChannelCommand {
  startService,
  stopService,
  onTracking,
  forceTracking,
  closeDatabase,
  triggerStanding,
  triggerMoving,
  skipRecord;

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
    //DartPluginRegistrant.ensureInitialized();
    if (Platform.isAndroid) {
      //PathProviderAndroid.registerWith();
    } else if (Platform.isIOS) {
      //PathProviderIOS.registerWith();
    }
    bool serviceIsRunning = true;
    Tracker tracker = Tracker();

    await DB.openDatabase();

    Future<void> executeTracker() async {
      try {
        Cache.reload();
        service.invoke(BackgroundChannelCommand.onTracking.toString(),
            await tracker.track());
      } catch (e, stk) {
        logger.error('background tracking: $e', stk);
      }
      try {
        NotificationChannel.sendTrackingUpdateNotification(
            title: 'Tick Update',
            message: 'Status: ${tracker.trackingStatus?.name.toUpperCase()}'
                ' since ${util.formatDuration(tracker.statusDuration)}',
            details: NotificationChannel.ongoigTrackingUpdateConfiguration);
      } catch (e) {
        logger.warn('send Notification: $e');
      }
    }

    service
        .on(BackgroundChannelCommand.triggerStanding.toString())
        .listen((_) async {
      tracker.triggeredTrackingStatus = TrackingStatus.standing;
    });
    service
        .on(BackgroundChannelCommand.skipRecord.toString())
        .listen((map) async {
      final skip = TypeAdapter.deserializeBool(
          map?[BackgroundChannelCommand.skipRecord.toString()]);
      tracker.skipRecord = skip;
    });
    service
        .on(BackgroundChannelCommand.triggerMoving.toString())
        .listen((_) async {
      tracker.triggeredTrackingStatus = TrackingStatus.moving;
    });

    // stop service
    service.on(BackgroundChannelCommand.stopService.toString()).listen((_) {
      serviceIsRunning = false;
      service.stopSelf();
    });

    // force tracking
    service
        .on(BackgroundChannelCommand.forceTracking.toString())
        .listen((_) async {
      executeTracker();
    });

    // close database
    service.on(BackgroundChannelCommand.closeDatabase.toString()).listen((_) {
      service.stopSelf();
      DB.closeDatabase();
    });

    try {
      const Cache cache = Cache.appSettingBackgroundTrackingInterval;
      while (serviceIsRunning) {
        await Future.microtask(executeTracker);
        try {
          await Future.delayed(await cache
              .load<Duration>(AppUserSetting(cache).defaultValue as Duration));
        } catch (e) {
          try {
            logger.warn(
                'Fetching background interval delay failed. Fallback to default');
            Future.delayed(AppUserSetting(cache).defaultValue as Duration);
          } catch (e) {
            const inv = 30;
            logger.error(
                'Get default background interval delay failed. Fallback to fixed $inv seconds',
                StackTrace.current);
            Future.delayed(const Duration(seconds: inv));
          }
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

  static void invoke(BackgroundChannelCommand command,
      [Map<String, dynamic>? arg]) {
    FlutterBackgroundService().invoke(command.toString(), arg);
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

        notificationChannelId:
            NotificationChannel.ongoingTrackingUpdateChannelName,
        initialNotificationTitle: 'Chaos Tours on start',
        initialNotificationContent: 'Initializing Background Tracking...',
        foregroundServiceNotificationId:
            NotificationChannel.ongoingTrackingUpdateChannelId,
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
