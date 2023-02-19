import 'dart:io';
import 'package:flutter/material.dart';
//
import 'package:chaostours/notifications.dart';
import 'package:chaostours/permissions.dart';

//
import 'package:chaostours/view/app_widgets.dart';

@override
class WidgetPermissionsPage extends StatefulWidget {
  const WidgetPermissionsPage({super.key});
  @override
  State<WidgetPermissionsPage> createState() => _WidgetPermissionsPage();
}

class _WidgetPermissionsPage extends State<WidgetPermissionsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget pageBody() {
    return ListView(
      children: [
        const ElevatedButton(
          onPressed: Permissions.requestLocationPermission,
          child: Text('Request background location permission'),
        ),
        if (Platform.isAndroid) ...[
          const Text(
              'You need to check the option "ALWAYS allow location lookup\n\n'
              'This permission on android is only needed since API Level 33:\n'
              'Android 13, Tiramisu, API Level 33 since August 15, 2022\n'
              'https://en.wikipedia.org/wiki/Android_version_history#Overview'),
        ],
        const ElevatedButton(
          onPressed: Permissions.requestNotificationPermission,
          child: Text('Request Notification permission'),
        ),
        ElevatedButton(
          child: const Text('Test notification'),
          onPressed: () => Notifications()
              .send('Hello from Chaos Tours', 'The ultimate Tracking app'),
        ),
        /*
                const ElevatedButton(
                  onPressed: Tracking.startTracking,
                  child: Text('Start Tracking'),
                ),
                const ElevatedButton(
                  onPressed: Tracking.stopTracking,
                  child: Text('Stop Tracking'),
                ),
                */
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context, body: pageBody());
  }
}
