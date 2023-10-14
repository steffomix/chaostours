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
import 'package:chaostours/app_logger.dart';
import 'package:chaostours/ticker.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/app_database.dart';

class AppLoader {
  static AppLogger logger = AppLogger.logger<AppLoader>();

  static Future<bool> get preload => _preload ??= _preloadApp();
  static Future<bool>? _preload;

  // /data/user/0/com.stefanbrinkmann.chaosToursUnlimited/shared_prefs/FlutterSharedPreferences.xml
  static Future<void> dbToFile() async {
    var dbDir = await DB.getDBDir();
    var downloadDir = io.Directory('/storage/emulated/0/Download');
    io.File(dbDir.path).copy('${downloadDir.path}/${DB.dbFile}');
  }

  static Future<void> fileToDb() async {
    var dbDir = await DB.getDBDir();
    var downloadDir = io.Directory('/storage/emulated/0/Download');
    io.File('${downloadDir.path}/${DB.dbFile}').copy(dbDir.path);
  }

  ///
  /// preload recources
  static Future<bool> _preloadApp() async {
    try {
      await AppLogger.clearLogs();
      // reset background logger
      //await Cache.setValue<List<String>>(CacheKeys.backgroundLogger, []);
      //var downloadFiles = await downloadDir.list().toList();
      //await fileToDb();
      AppLogger.globalLogLevel = LogLevel.verbose;
      logger.important('start Preload sequence...');
      //await DB.deleteDatabase(await DB.getPath());
      logger.log('open Database...');
      await DB.openDatabase(create: true);
      logger.log('Database opened');
      logger.log('get WEB SSL key from assets');
      await webKey();

      //
      if (AppSettings.backgroundTrackingEnabled) {
        try {
          logger.log('initialize background tracking');
          await BackgroundTracking.initialize();
        } catch (e, stk) {
          logger.error('initialize background tracking', stk);
        }
        try {
          logger.log('start background tracking');
          await BackgroundTracking.startTracking();
        } catch (e, stk) {
          logger.error('start background tracking', stk);
        }
      }

      logger.log('start app tick');
      Ticker.startAppTick();

      logger.log('start databridge');
      DataBridge.instance.startService();
    } catch (e, stk) {
      logger.fatal('preload $e', stk);
      return false;
    }

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
