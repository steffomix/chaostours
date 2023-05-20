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
import 'package:chaostours/background_process/tracking.dart';
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
      Logger.globalLogLevel = LogLevel.verbose;
      logger.important('start Preload sequence...');
      await webKey();
      await DataBridge.instance.reload();
      await Globals.loadSettings();
      await Globals.saveSettings();
      await DataBridge.instance.loadCache();
      await DataBridge.instance.loadTriggerStatus();

      await ModelTrackPoint.open();
      await ModelUser.open();
      await ModelTask.open();
      await ModelAlias.open();

      /// check if alias is available
      if (await PermissionChecker.checkLocation()) {
        try {
          DataBridge.instance.trackPointAliasIdList =
              await Cache.setValue<List<int>>(
                  CacheKeys.cacheBackgroundAliasIdList,
                  ModelAlias.nextAlias(gps: await GPS.gps())
                      .map((e) => e.id)
                      .toList());
        } catch (e, stk) {
          logger.error('preload alias: $e', stk);
        }
      }
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

  //
  static Future<void> loadAssetDatabase() async {
    logger.important('load databasde from asset');

    ///
    if (ModelAlias.length < 1) {
      await ModelAlias.write();
    }
    if (ModelUser.length < 1) {
      await ModelUser.write();
    }
    if (ModelTask.length < 1) {
      await ModelTask.write();
    }
  }

  static Future<void> ticks() async {
    DataBridge.instance.startService();
    _appTick();
  }

  static Future<void> _appTick() async {
    while (true) {
      var event = EventOnAppTick();
      try {
        EventManager.fire<EventOnAppTick>(event);
      } catch (e, stk) {
        logger.error('appTick #${event.id} failed: $e', stk);
      }
      await Future.delayed(Globals.appTickDuration);
    }
  }
}
