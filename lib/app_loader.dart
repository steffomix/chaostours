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

import 'package:chaostours/address.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:flutter/services.dart';
import 'dart:io' as io;

///
import 'package:chaostours/tracking.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/database.dart';
import 'runtime_data.dart';

class AppLoader {
  static Logger logger = Logger.logger<AppLoader>();

  static Future<bool> get preload => _preload ??= _preloadApp();
  static Future<bool>? _preload;

  ///
  /// preload recources
  static Future<bool> _preloadApp() async {
    try {
      Logger.globalLogLevel = LogLevel.verbose;
      logger.important('start Preload sequence...');

      //
      logger.log('open Database...');
      await DB.openDatabase(create: true);
      logger.log('Database opened');

      var count = await ModelAlias.count();
      if (count == 0) {
        logger.log('create initial alias');
        try {
          GPS gps = await GPS.gps();
          await ModelAlias(
                  gps: gps,
                  lastVisited: DateTime.now(),
                  title: (await Address(gps).lookupAddress()).toString(),
                  description: 'Initial Alias created by System on first run.'
                      'Feel free to change it for your needs.')
              .insert();
        } catch (e) {
          logger
              .warn('Create initial alias failed. No GPS Permissions granted?');
        }
      }

      //
      logger.log('get WEB SSL key from assets');
      await webKey();

      //
      if (await Cache.appSettingBackgroundTrackingEnabled.load<bool>(true)) {
        // wait a little
        await Future.delayed(const Duration(seconds: 3));
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
    } catch (e, stk) {
      logger.fatal('preload $e', stk);
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
