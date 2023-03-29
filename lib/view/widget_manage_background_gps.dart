import 'package:chaostours/cache.dart';
import 'package:flutter/material.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/background_process/tracking.dart';
import 'package:chaostours/event_manager.dart';

class WidgetManageBackgroundGps extends StatefulWidget {
  const WidgetManageBackgroundGps({Key? key}) : super(key: key);

  @override
  State<WidgetManageBackgroundGps> createState() =>
      _WidgetManageBackgroundGpsState();
}

class _WidgetManageBackgroundGpsState extends State<WidgetManageBackgroundGps> {
  List<Widget> items = [
    AppWidgets.loading('Checking Background Tracking Status')
  ];
  Widget? trackingSwitch;
  @override
  void initState() {
    EventManager.listen<EventOnCacheLoaded>(onCacheLoaded);
    checkTracking();
    super.initState();
  }

  @override
  void dispose() {
    EventManager.remove<EventOnCacheLoaded>(onCacheLoaded);
    super.dispose();
  }

  void onCacheLoaded(EventOnCacheLoaded e) {
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

  void updateBody() {
    if (trackingSwitch == null) {
      return;
    }
    Cache cache = Cache.instance;
    items = [
      const Text(
          'Wenn das Hintergrund GPS nicht wie erwartet funktioniert, versuchen sie ihn neu zu startetn.'),
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
      const Text('Background Cache Data',
          style: TextStyle(fontWeight: FontWeight.bold)),
      Text(
          'Last Status Change GPS Position:\n ${cache.lastStatusChange?.toSharedString()}'),
      AppWidgets.divider(),
      Text(
          'Status calculation GPS Positions (${cache.calcGpsPoints.length}):\n ${cache.calcGpsPoints.map((e) => e.toSharedString()).join('\n')}'),
      AppWidgets.divider(),
      Text(
          'Status calculation GPS Positions (${cache.smoothGpsPoints.length}):\n ${cache.smoothGpsPoints.map((e) => e.toSharedString()).join('\n')}'),
      AppWidgets.divider(),
      Text(
          'All GPS Points (${cache.gpsPoints.length}):\n${cache.gpsPoints.map((e) => e.toSharedString()).join('\n')}')
    ];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context,
        body: Container(
            padding: const EdgeInsets.all(5),
            child: ListView(children: [...items])));
  }
}
