import 'dart:async';
import 'dart:io';
//import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:flutter/material.dart';
//import 'package:permission_handler/permission_handler.dart';
//
import 'package:chaostours/notifications.dart';
import 'package:chaostours/permissions.dart';
import 'package:chaostours/tracking.dart';

@override
class WidgetSettingsPermissions extends StatefulWidget {
  const WidgetSettingsPermissions({super.key});
  @override
  State<WidgetSettingsPermissions> createState() =>
      _WidgetSettingsPermissionsState();
}

class _WidgetSettingsPermissionsState extends State<WidgetSettingsPermissions> {
  List<String> _locations = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: Column(
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
                  onPressed: () => Notifications().send(
                      'Hello from Chaos Tours', 'The ultimate Tracking app'),
                ),
                ElevatedButton(
                  onPressed: Tracking().startTracking,
                  child: const Text('Ok, let\'s go! Start Tracking'),
                ),
                ElevatedButton(
                  onPressed: Tracking().stopTracking,
                  child: const Text('Stop Tracking'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.black12,
            height: 2,
          ),
        ],
      ),
    );
  }
/*
  Future<void> _getTrackingStatus() async {
    isTracking = await BackgroundLocationTrackerManager.isTracking();
    setState(() {});
  }

  Future<void> _requestLocationPermission() async {
    final result = await Permission.locationAlways.request();
    if (result == PermissionStatus.granted) {
      print('GRANTED'); // ignore: avoid_print
    } else {
      print('NOT GRANTED'); // ignore: avoid_print
    }
  }

  Future<void> _requestNotificationPermission() async {
    final result = await Permission.notification.request();
    if (result == PermissionStatus.granted) {
      print('GRANTED'); // ignore: avoid_print
    } else {
      print('NOT GRANTED'); // ignore: avoid_print
    }
  }
*/
}
