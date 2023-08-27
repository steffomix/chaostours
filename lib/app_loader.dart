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

import 'package:flutter/services.dart';
import 'dart:io' as io;

///
import 'package:chaostours/tracking.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/permission_checker.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/database.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  static Future<void> dbToFile() async {
    var dbPath = await DB.getPath();
    var downloadDir = io.Directory('/storage/emulated/0/Download');
    io.File(dbPath).copy('${downloadDir.path}/chaostours.sqlite');
  }

  static Future<void> fileToDb() async {
    var dbPath = await DB.getPath();
    var downloadDir = io.Directory('/storage/emulated/0/Download');
    io.File('${downloadDir.path}/chaostours.sqlite').copy(dbPath);
  }

  ///
  /// preload recources
  static Future<void> preload() async {
    try {
      //await AppDatabase.deleteDb();
    } catch (e) {
      logger.warn(e);
    }

    try {
      // reset background logger
      //await Cache.setValue<List<String>>(CacheKeys.backgroundLogger, []);
      //var downloadFiles = await downloadDir.list().toList();
      //await fileToDb();
      await Future.delayed(const Duration(seconds: 1));
      await DB.open();
      Logger.globalLogLevel = LogLevel.verbose;
      logger.important('start Preload sequence...');
      await webKey();
      await DataBridge.instance.reload();
      await AppSettings.loadSettings();
      await AppSettings.saveSettings();
      await DataBridge.instance.loadCache();

      //
      await BackgroundTracking.initialize();
      if (await PermissionChecker.checkLocation() &&
          AppSettings.backgroundTrackingEnabled) {
        await BackgroundTracking.startTracking();
      }
      ticks();
    } catch (e, stk) {
      logger.error('preload $e', stk);
    }
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

  static Future<void> ticks() async {
    DataBridge.instance.startService();
    _appTick();
  }

  static Future<void> _appTick() async {
    var dur = const Duration(seconds: 1);
    while (true) {
      try {
        EventManager.fire<EventOnAppTick>(EventOnAppTick());
        AppSettings.appTicks++;
      } catch (e, stk) {
        logger.error(
            'appTick ${DateTime.now().toIso8601String()} failed: $e', stk);
      }
      await Future.delayed(dur);
    }
  }
}
