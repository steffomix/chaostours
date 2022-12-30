import 'dart:async';
import 'package:chaostours/enum.dart';
import 'package:chaostours/events.dart';
import 'package:flutter/material.dart';
import 'widget_trackpoints_listview.dart';
import 'widget_trackpoint-editview.dart';
import 'package:chaostours/log.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static StreamSubscription? onScreenChanged;
  static AppBodyScreens _bodyId = AppBodyScreens.trackPointListView;

  _AppState() {
    onScreenChanged ??= eventBusAppBodyScreenChanged
        .on<AppBodyScreens>()
        .listen(onAppBodyChanged);
  }

  Widget body() {
    switch (_bodyId) {
      case AppBodyScreens.trackPointListView:
        return const TrackPointListView();
      case AppBodyScreens.trackPointEditView:
        return const TrackPointEditView();
      default:
        return const TrackPointListView();
    }
  }

  AppBar appbar() {
    return AppBar(title: const Text('ChaosTours'));
  }

  onAppBodyChanged(AppBodyScreens id) {
    _bodyId = id;
    setState(() {});
  }

  Drawer drawer() {
    return Drawer(
        child: ListView(padding: EdgeInsets.zero, children: const [
      ListTile(title: Text('test')),
      ListTile(title: Text('test2'))
    ]));
  }

  ListTile trackPoint(int id) {
    String title = 'TrackPoint $id';
    return ListTile(title: Text(title));
  }

  onTabBottomNavigationBar(int id) {}

  BottomNavigationBar bottomNavigationBar() {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.keyboard_arrow_left), label: 'x'),
          BottomNavigationBarItem(icon: Icon(Icons.location_city), label: 'x'),
          BottomNavigationBarItem(
              icon: Icon(Icons.keyboard_arrow_right), label: 'x'),
        ],
        onTap: (int id) {
          eventBusTapBottomNavBarIcon.fire(Tapped(id));
        });
  }

  @override
  Widget build(BuildContext context) {
    Widget myBody = const Text('Waiting for TrackPoints...');
    try {
      myBody = const TrackPointListView();
    } catch (e) {
      logWarn('Waiting for TrackPoints...', e);
    }
    return MaterialApp(
        home: Scaffold(
      appBar: appbar(),
      drawer: drawer(),
      body: body(),
      bottomNavigationBar: bottomNavigationBar(),
    ));
  }

  // ignore: unused_element
  void _onBottomNavTapped(int index) {
    setState(() {});
  }
}
