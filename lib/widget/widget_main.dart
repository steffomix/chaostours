import 'dart:async';
import 'package:flutter/material.dart';
//
import 'package:chaostours/widget/widget_trackpoints_listview.dart';
import 'package:chaostours/widget/widget_drawer.dart';
import 'package:chaostours/enum.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/events.dart';
import 'package:chaostours/event_manager.dart';

class App extends StatefulWidget {
  const App({super.key});
  // app main pane

  @override
  State<App> createState() => _AppState();
}

///
///
///
class _AppState extends State<App> {
  static _AppState? _instance;
  _AppState._() {
    EventManager.listen<EventOnMainPaneChanged>((EventOnMainPaneChanged p) {
      _pane = p.pane;
      logger.log('main pane changed to ${p.pane.runtimeType.toString()}');
      setState(() {});
    });
    EventManager.listen<EventOnTick>(onTick);
  }
  factory _AppState() => _instance ??= _AppState._();

  static Logger logger = Logger.logger<App>();
  static Widget? _pane;

  Widget get pane {
    return _pane ??= Panes.trackPointList.value;
  }

  void onTick(EventOnTick event) {
    // _pane = p.pane;
    setState(() {});
  }

  @override
  void dispose() {
    EventManager.remove<EventOnTick>(onTick);
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
          logger.log('BottomNavBar tapped but no method connected');
          //eventBusTapBottomNavBarIcon.fire(Tapped(id));
        });
  }

  @override
  Widget build(BuildContext context) {
    Widget myBody = const Text('Waiting for TrackPoints...');
    try {
      myBody = const WidgetTrackPointList();
    } catch (e, stk) {
      logger.fatal('create WidgetTrackPointList failed', stk);
    }
    return MaterialApp(
        home: Scaffold(
      appBar: appbar(),
      drawer: const WidgetDrawer(),
      body: pane,
    ));
  }

  // ignore: unused_element
  void _onBottomNavTapped(int index) {
    setState(() {});
  }
}
