import 'dart:async';
import 'package:chaostours/events.dart';
import 'package:flutter/material.dart';
import 'package:chaostours/widget/widget_trackpoints_listview.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/config.dart';

class App extends StatefulWidget {
  const App({super.key});
  // app main pane

  @override
  State<App> createState() => _AppState();
}

///
///
///
///
class _AppState extends State<App> {
  static StreamSubscription? onScreenChanged;

  _AppState() {
    onScreenChanged ??=
        eventBusMainPaneChanged.on<Widget>().listen((Widget pane) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    //onScreenChanged?.cancel();
    super.dispose();
  }

  AppBar appbar() {
    return AppBar(title: const Text('ChaosTours'));
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
      myBody = const WidgetModelTrackPointList();
    } catch (e) {
      logWarn('Waiting for TrackPoints...', e);
    }
    if (AppConfig.debugMode) {
      return MaterialApp(
          home: Scaffold(
        appBar: appbar(),
        drawer: drawer(),
        body: Globals.mainPane,
        bottomNavigationBar: bottomNavigationBar(),
      ));
    } else {
      return MaterialApp(home: Scaffold(body: Globals.mainPane));
    }
  }

  // ignore: unused_element
  void _onBottomNavTapped(int index) {
    setState(() {});
  }
}
