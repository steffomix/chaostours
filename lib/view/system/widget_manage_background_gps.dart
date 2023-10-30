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

import 'package:flutter/material.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/tracking.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/event_manager.dart';
//import 'package:chaostours/calendar.dart';

class WidgetManageBackgroundGps extends StatefulWidget {
  const WidgetManageBackgroundGps({Key? key}) : super(key: key);

  @override
  State<WidgetManageBackgroundGps> createState() =>
      _WidgetManageBackgroundGpsState();
}

class _WidgetManageBackgroundGpsState extends State<WidgetManageBackgroundGps> {
  List<Widget> items = [
    AppWidgets.loading(const Text('Checking Background Tracking Status'))
  ];
  Widget? trackingSwitch;
  double latShift = 0;
  double lonShift = 0;
  @override
  void initState() {
    DataBridge.instance.startService();
    EventManager.listen<EventOnCacheLoaded>(onCacheLoaded);
    checkTracking();
    super.initState();
  }

  @override
  void dispose() {
    EventManager.remove<EventOnCacheLoaded>(onCacheLoaded);
    super.dispose();
  }

  void onCacheLoaded(EventOnCacheLoaded e) async {
    updateBody();
  }

  Future<void> checkTracking() async {
    bool isTracking = await BackgroundTracking.isTracking();

    trackingSwitch = ListTile(
        leading: isTracking
            ? const Icon(Icons.done, color: Colors.green)
            : const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Status Hintergrund GPS'),
        subtitle: const Text('Hintergrund GPS starten/stoppen'),
        trailing: IconButton(
          icon: isTracking
              ? const Icon(Icons.stop)
              : const Icon(Icons.play_arrow),
          onPressed: () async {
            if (isTracking) {
              await BackgroundTracking.stopTracking();
            } else {
              await BackgroundTracking.initialize();
              await BackgroundTracking.startTracking();
            }
            Future.delayed(const Duration(milliseconds: 200), checkTracking);
          },
        ));

    updateBody();
  }

  Future<void> updateBody() async {
    latShift = await Cache.getValue<double>(CacheKeys.gpsLatShift, 0.0);
    lonShift = await Cache.getValue<double>(CacheKeys.gpsLonShift, 0.0);
    if (trackingSwitch == null) {
      return;
    }
    DataBridge bridge = DataBridge.instance;
    items = [
      const Text(
          'Wenn das Hintergrund GPS nicht wie erwartet funktioniert, versuchen sie es neu zu starten.'),
      ElevatedButton(
          child: const Text('Hintergrund GPS neustarten'),
          onPressed: () async {
            await BackgroundTracking.stopTracking().then((_) {
              checkTracking();
            });

            await Future.delayed(const Duration(milliseconds: 200));
            await BackgroundTracking.startTracking().then((_) {
              checkTracking();
            });
          }),
      AppWidgets.divider(),
      trackingSwitch!,
      AppWidgets.divider(),
      ElevatedButton(
          child: const Text('Clear Cache'),
          onPressed: () async {
            await Cache.clear();
            await AppSettings.reset();
            await updateBody();
          }),
      AppWidgets.divider(),
      Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        ElevatedButton(
          child: Text('++lat $latShift'),
          onPressed: () async {
            await Cache.setValue<double>(
                CacheKeys.gpsLatShift, latShift + 0.001);
            await updateBody();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              child: Text('--lon $lonShift'),
              onPressed: () async {
                await Cache.setValue<double>(
                    CacheKeys.gpsLonShift, lonShift - 0.001);
                await updateBody();
              },
            ),
            ElevatedButton(
              child: Text('++lon $lonShift'),
              onPressed: () async {
                await Cache.setValue<double>(
                    CacheKeys.gpsLonShift, lonShift + 0.001);
                await updateBody();
              },
            ),
          ],
        ),
        ElevatedButton(
          child: Text('--lat $latShift'),
          onPressed: () async {
            await Cache.setValue<double>(
                CacheKeys.gpsLatShift, latShift - 0.001);
            await updateBody();
          },
        ),
      ]),
      AppWidgets.divider(),
      const Center(
          child: Text('Background Cache Data',
              style: TextStyle(fontWeight: FontWeight.bold))),
      AppWidgets.divider(),
      AppWidgets.divider(),
      Text('Selected Calendar ID: ${bridge.selectedCalendarId}'),
      AppWidgets.divider(),
      Text('Last Calendar Event ID: ${bridge.lastCalendarEventIds}'),
      AppWidgets.divider(),
      Text('Current Tracking Status: ${bridge.trackingStatus.name}'),
      AppWidgets.divider(),
      Text('Status change triggered: ${bridge.triggeredTrackingStatus.name}'),
      AppWidgets.divider(),
      Text(
          'Gps status standing: ${bridge.trackPointGpsStartStanding?.toString()}'),
      AppWidgets.divider(),
      Text('Gps status moving: ${bridge.trackPointGpsStartMoving?.toString()}'),
      AppWidgets.divider(),
      Text('Alias IDs: ${bridge.trackPointAliasIdList.join(',')}'),
      AppWidgets.divider(),
      Text('Task IDs: ${bridge.trackPointTaskIdList.join(',')}'),
      AppWidgets.divider(),
      Text('User IDs: ${bridge.trackPointUserIdList.join(',')}'),
      AppWidgets.divider(),
      Text('User notes: ${bridge.trackPointUserNotes}'),
      AppWidgets.divider(),
      Text(
          'Last Status Change:\n ${bridge.trackPointGpsStartMoving?.toString()}'),
      AppWidgets.divider(),
      Text(
          'Status calculation GPS Positions (${bridge.calcGpsPoints.length}):\n ${bridge.calcGpsPoints.map((e) => e.toString()).join('\n')}'),
      AppWidgets.divider(),
      Text(
          'Smoothed GPS Positions (${bridge.smoothGpsPoints.length}):\n ${bridge.smoothGpsPoints.map((e) => e.toString()).join('\n')}'),
      AppWidgets.divider(),
      Text(
          'All GPS Points (${bridge.gpsPoints.length}):\n${bridge.gpsPoints.map((e) => e.toString()).join('\n')}')
    ];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: Container(
            padding: const EdgeInsets.all(5),
            child: ListView(children: [...items])),
        appBar: AppBar(title: const Text('Cache & Backgr. GPS')));
  }
}