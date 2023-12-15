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

import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannel {
  static const String backgroundNotificationId =
      'chaostous_foreground_service_id';

  static const String backgroundNotificationTitle =
      'Chaos Tours Background Service';
  static const String backgroundNotificationDescription =
      'Chaos Tours notification channel';
  static const String notificationIcon = 'ic_bg_service_small';
  static const int foregroundServiceNotificationId = 777;

  static Future<void> initialize() async {
    /// OPTIONAL, using custom notification channel id
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      backgroundNotificationId, // id
      backgroundNotificationTitle, // title
      description: backgroundNotificationDescription, // description
      importance: Importance.high, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings(notificationIcon),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}
