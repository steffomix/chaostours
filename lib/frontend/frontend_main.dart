import 'package:flutter/material.dart';
import '../track_point.dart';
import '../tracking_event.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  void onTrackingStatusChanged(TrackPoint tp) {}

  _AppState() {
    TrackingStatusChangedEvent.addListener(onTrackingStatusChanged);
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp();
  }

  // ignore: unused_element
  void _onBottomNavTapped(int index) {
    setState(() {});
  }
}
