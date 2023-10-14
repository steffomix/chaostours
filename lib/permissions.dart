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

import 'package:permission_handler/permission_handler.dart';
import 'package:chaostours/app_logger.dart';

class Permissions {
  static AppLogger logger = AppLogger.logger<Permissions>();
  static Permissions? _instance;
  Permissions._() {
    try {
      Permissions.requestLocationPermission();
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
    try {
      Permissions.requestNotificationPermission();
    } catch (e, stk) {
      logger.fatal(e.toString(), stk);
    }
  }
  factory Permissions() => _instance ??= Permissions._();

  static Future<void> requestNotificationPermission() async {
    final result = await Permission.notification.request();
    if (result == PermissionStatus.granted) {
      logger.log('Notification Permission GRANTED'); // ignore: avoid_print
    } else {
      logger.log('Notification Permission NOT GRANTED'); // ignore: avoid_print
    }
  }

  static Future<void> requestLocationPermission() async {
    final result = await Permission.locationAlways.request();
    if (result == PermissionStatus.granted) {
      logger.log('Location (GPS) Permission GRANTED'); // ignore: avoid_print
    } else {
      logger
          .log('Location (GPS) Permission NOT GRANTED'); // ignore: avoid_print
    }
  }
}
