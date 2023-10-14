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

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
import 'package:chaostours/app_logger.dart';

class Notifications {
  static AppLogger logger = AppLogger.logger<Notifications>();
  static Notifications? _instance;
  Notifications._() {
    _initialize();
  }
  factory Notifications() => _instance ??= Notifications._();
  //
  static int id = DateTime.now().millisecond;
  static FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool pluginInitialized = false;

  Future<void> _initialize() async {
    logger.log('initialize');
    if (pluginInitialized) return;
    pluginInitialized = (await plugin.initialize(
            const InitializationSettings(
                android: AndroidInitializationSettings('mipmap/ic_launcher')),
            onDidReceiveNotificationResponse: (NotificationResponse res) {
          ///
        }, onDidReceiveBackgroundNotificationResponse:
                (NotificationResponse res) {
          ///
        })) ??
        false;
  }

  Future<void> onSelectNotification(String? data) async {
    data ??= '-no Data-';
    logger.log('onSelectNotification Data: $data');
  }

  Future<void> send(String title, String text, {String data = ''}) async {
    logger.log('Send title: $title; text:text; data: data');
    FlutterLocalNotificationsPlugin().show(
      id,
      title,
      text,
      const NotificationDetails(
          android: AndroidNotificationDetails(
              'Notification Informations', 'Notification')),
    );
  }
}
