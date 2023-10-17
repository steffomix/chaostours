// ignore_for_file: deprecated_member_use

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

class PermissionChecker {
  static bool permissionsChecked = false;
  static bool permissionsOk = false;

  static Future<bool> checkAll() async {
    bool permLocation = await Permission.location.isGranted;
    bool permLocationAlways = await Permission.locationAlways.isGranted;
    permissionsChecked = true;
    if (permLocation &&
            permLocationAlways /*  &&
        permIgnoreBattery &&
        permManageExternalStorage &&
        permNotification &&
        permCalendar*/
        ) {
      permissionsOk = true;
      return true;
    }
    return false;
  }

  static Future<bool> checkLocation() async =>
      await Permission.locationAlways.isGranted;
  static Future<bool> checkLocationAlways() async =>
      await Permission.locationAlways.isGranted;
  static Future<bool> checkIgnoreBatteryOptimizations() async =>
      await Permission.ignoreBatteryOptimizations.isGranted;
  static Future<bool> checkManageExternalStorage() async =>
      await Permission.manageExternalStorage.isGranted;
  static Future<bool> checkNotification() async =>
      await Permission.notification.isGranted;
  static Future<bool> checkCalendar() async =>
      await Permission.calendar.isGranted;

  static Future<void> requestAll() async {
    await Permission.location.request();
    await Permission.locationAlways.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    await Permission.notification.request();
    await Permission.calendar.request();
  }
}
