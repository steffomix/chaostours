import 'dart:math';

import 'package:flutter/material.dart';
import 'geoCoding.dart';
import 'geoTracking.dart';
import 'geoLocation.dart';
import 'calendar.dart';
import 'logger.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'locationAlias.dart';

void main() async {
  // Thanks for: https://stackoverflow.com/a/69481863
  // add cert for https requests you can download here:
  // https://letsencrypt.org/certs/lets-encrypt-r3.pem
  WidgetsFlutterBinding.ensureInitialized();

  ByteData data =
      await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
  SecurityContext.defaultContext
      .setTrustedCertificatesBytes(data.buffer.asUint8List());

  //setup logger
  Logger.debugMode = true;
  CalendarHandler c = CalendarHandler();
  LocationAlias l = LocationAlias(0, 0);

  // start app
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  //GeoTracking _tracking;
  static bool _gpsEnabled = false;
  static const String _appName = 'Chaos Tours';
  static int _bottomNavIndex = 0;

  static CalendarHandler c = CalendarHandler();

  // last found address (can be incomplete or even empty)
  String _addr = '';

  _AppState() {
    GPSLookup((bool enable) {
      _gpsEnabled = enable;
      if (_gpsEnabled) {
        GeoTracking((GPS gps) {
          _addr = gps.address.asString;
          setState(() {});
        }).startTracking();
      }
    });
  }

  void _onBottomNavTapped(int index) {
    //c.addEvent('title', 'description', ['tasks'], Address.empty());
    try {
      _bottomNavIndex = index;
      log('Tapped Bottomnavigation index: $index');
      c.addEvent(c.createEvent(
          DateTime.now(),
          DateTime.now().add(const Duration(hours: 1)),
          ['t1', 't2'],
          Address.empty()));
    } catch (e) {
      log(e.toString());
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
          return Center(child: Text('Page 0: Address: $_addr '));
        }
      case 1:
        {
          return Center(child: Text('Page 1 Address: $_addr '));
        }
      default:
        return Center(child: Text('Start Page 0: Address: $_addr '));
    }
  }

  BottomNavigationBar _bottomNav() {
    return BottomNavigationBar(items: const <BottomNavigationBarItem>[
      BottomNavigationBarItem(
          icon: Icon(Icons.toggle_off_outlined), label: 'Start'),
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
