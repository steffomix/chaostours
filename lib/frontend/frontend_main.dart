import 'dart:async';
import 'package:chaostours/events.dart';
import 'package:flutter/material.dart';
import 'widget_trackpoints_listview.dart';
import '../log.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  _AppState();
  AppBar appbar() {
    return AppBar(title: const Text('Title'));
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

  BottomNavigationBar bottomNavigationBar() {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.tap_and_play), label: 'but 1'),
          BottomNavigationBarItem(
              icon: Icon(Icons.accessible_forward_outlined), label: 'but 2')
        ],
        onTap: (int id) {
          onTapEvent.fire(Tapped());
        });
  }

  ListView listView() {
    return ListView(children: const [Text('test'), Text('test2')]);
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
      body: myBody,
      bottomNavigationBar: bottomNavigationBar(),
    ));
  }

  // ignore: unused_element
  void _onBottomNavTapped(int index) {
    setState(() {});
  }
}
