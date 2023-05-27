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
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/permission_checker.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/gps.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  ///
  /// preload recources
  static Future<void> preload() async {
    try {
      // reset background logger
      //await Cache.setValue<List<String>>(CacheKeys.backgroundLogger, []);
      Logger.globalLogLevel = LogLevel.verbose;
      logger.important('start Preload sequence...');
      await webKey();
      await DataBridge.instance.reload();
      await Globals.loadSettings();
      await Globals.saveSettings();
      await DataBridge.instance.loadCache();

      await ModelTrackPoint.open();
      await ModelUser.open();
      await ModelTask.open();
      await ModelAlias.open();

      //
      await BackgroundTracking.initialize();
      if (await PermissionChecker.checkLocation() &&
          Globals.backgroundTrackingEnabled) {
        await BackgroundTracking.startTracking();
      }
      ticks();
    } catch (e, stk) {
      logger.error('preload $e', stk);
    }
  }

  ///
  /// load ssh key for https connections
  static Future<void> webKey() async {
    ByteData data =
        await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
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
        Globals.appTicks++;
      } catch (e, stk) {
        logger.error(
            'appTick ${DateTime.now().toIso8601String()} failed: $e', stk);
      }
      await Future.delayed(dur);
    }
  }
}
