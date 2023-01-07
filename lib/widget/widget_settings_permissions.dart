import 'dart:async';
import 'dart:io';

import 'package:background_location_tracker/background_location_tracker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chaostours/permission.dart';

@override
class WidgetSettingsPermissions extends StatefulWidget {
  const WidgetSettingsPermissions({super.key});
  @override
  State<WidgetSettingsPermissions> createState() =>
      _WidgetSettingsPermissionsState();
}

class _WidgetSettingsPermissionsState extends State<WidgetSettingsPermissions> {
  var isTracking = false;

  Timer? _timer;
  List<String> _locations = [];

  @override
  void initState() {
    super.initState();
    _getTrackingStatus();
    _startLocationsUpdatesStream();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
                MaterialButton(
                  onPressed: _requestLocationPermission,
                  child: const Text('Request location permission'),
                ),
                if (Platform.isAndroid) ...[
                  const Text(
                      'Permission on android is only needed starting from sdk 33.'),
                ],
                MaterialButton(
                  onPressed: _requestNotificationPermission,
                  child: const Text('Request Notification permission'),
                ),
                MaterialButton(
                  child: const Text('Send notification'),
                  onPressed: () => sendNotification('Hello from another world'),
                ),
                MaterialButton(
                  onPressed: isTracking
                      ? null
                      : () async {
                          await BackgroundLocationTrackerManager
                              .startTracking();
                          setState(() => isTracking = true);
                        },
                  child: const Text('Start Tracking'),
                ),
                MaterialButton(
                  onPressed: isTracking
                      ? () async {
                          await LocationDao().clear();
                          await _getLocations();
                          await BackgroundLocationTrackerManager.stopTracking();
                          setState(() => isTracking = false);
                        }
                      : null,
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
          const Text('Locations'),
          MaterialButton(
            onPressed: _getLocations,
            child: const Text('Refresh locations'),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_locations.isEmpty) {
                  return const Text('No locations saved');
                }
                return ListView.builder(
                  itemCount: _locations.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      _locations[index],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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

  Future<void> _getLocations() async {
    final locations = await LocationDao().getLocations();
    setState(() {
      _locations = locations;
    });
  }

  void _startLocationsUpdatesStream() {
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(milliseconds: 250), (timer) => _getLocations());
  }
}
