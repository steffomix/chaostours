// ignore_for_file: prefer_const_constructors

import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/log.dart';
import 'package:chaostours/trackpoint.dart';
import 'package:chaostours/tracking_calendar.dart';
import 'package:chaostours/globals.dart';

void main() async {
  // Thanks for: https://stackoverflow.com/a/69481863
  // add cert for https requests you can download here:
  // https://letsencrypt.org/certs/lets-encrypt-r3.pem
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Chaos Tours App",
      notificationText:
          "Diese Meldung wird benötigt damit Chaos Tours im Hintergrund läuft.",
      notificationImportance: AndroidNotificationImportance.Default,
      notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'drawable'), // Default is ic_launcher from folder mipmap
    );
    bool hasPermissions = await FlutterBackground.hasPermissions;
    if (!hasPermissions) {
      bool success =
          await FlutterBackground.initialize(androidConfig: androidConfig);
    }
  } catch (e) {
    logError(e);
  }
  try {
    bool success = await FlutterBackground.enableBackgroundExecution();
  } catch (e) {
    logError(e);
  }
  // set loglevel
  Logger.level = Level.info;

  // preload recources
  await RecourceLoader.preload();

  // instantiate TrackingCalendar singelton
  TrackingCalendar();

  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Globals.version = packageInfo.version;
  } catch (e) {
    logError(e);
  }

  // start gps tracking
  TrackPoint.startTracking();

  // start frontend
  runApp(Globals.app);
}


/*
class App extends StatefulWidget {
  const App({super.key});q

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  //GeoTracking _tracking;
  static const String _appName = 'Chaos Tours';
  static int _bottomNavIndex = 0;
  static double _lat = 0;
  static String message = '';

  _AppState() {
    TrackingStatusChangedEvent.addListener((TrackingStatusChangedEvent e) {
      bool start = e.status == TrackPoint.statusStart;
      String address = e.address.asString;

      message =
          'Von ${e.trackPointStart.time.toIso8601String()} bis ${e.trackPointStop.time.toIso8601String()}\n';
      message += start ? 'Start von' : 'Stop bei';
      message += ' $address \n';
      message += 'um ${DateTime.now().toString()}\n';
      message += start
          ? 'nach ${e.time}'
          : 'nach ${e.distanceMoved / 1000}km \nin ${e.time}';
      setState(() {});
    });
    TrackPoint.startTracking();
    //TrackingCalendar();
  }

  void _onBottomNavTapped(int index) {
    _bottomNavIndex = index;
    switch (index) {
      case 0:
        {
          GPS.move();
          break;
        }
      case 1:
        {
          break;
        }
      default:
        {}
    }
    setState(() {});
  }

  String _title() {
    return _appName;
  }

  AppBar _appbar() {
    return AppBar(
        leading: const Icon(
          Icons.swap_calls,
          size: 40,
          color: Color.fromARGB(255, 134, 15, 119),
          semanticLabel: 'Chaos',
        ),
        title: const Text(
          _appName,
        ),
        toolbarHeight: 60,
        actions: <Widget>[
          Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 40, 0),
              child: IconButton(
                icon: const Icon(Icons.settings, size: 20),
                onPressed: () {},
              ))
        ]);
  }

  Center _body() {
    switch (_bottomNavIndex) {
      case 0:
        {
          return Center(child: Text(message));
        }
      case 1:
        {
          return const Center(child: Text(''));
        }
      default:
        return const Center(child: Text(''));
    }
  }

  BottomNavigationBar _bottomNav() {
    return BottomNavigationBar(items: const <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: Icon(Icons.arrow_left), label: 'move'),
      BottomNavigationBarItem(
          icon: Icon(Icons.toggle_on_rounded), label: 'Arbeiten'),
    ], onTap: _onBottomNavTapped, currentIndex: _bottomNavIndex);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: _title(),
        home: Scaffold(
            appBar: _appbar(),
            body: _body(),
            bottomNavigationBar: _bottomNav()));
  }
}
*/