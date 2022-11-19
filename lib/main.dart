import 'package:flutter/material.dart';
import 'geoCoding.dart';
import 'geoLocation.dart';
import 'logger.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() async {
  // https://stackoverflow.com/a/69481863
  WidgetsFlutterBinding.ensureInitialized();

  // https://letsencrypt.org/certs/lets-encrypt-r3.pem
  ByteData data =
      await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
  SecurityContext.defaultContext
      .setTrustedCertificatesBytes(data.buffer.asUint8List());

  Logger.debugMode = true;
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
  String _addr = '';
  int tapped = 0;

  _AppState() {
    GPSLookup(_enableGPS);
  }

  void _enableGPS(bool enable) {
    _gpsEnabled = enable;
    if (_gpsEnabled) {
      GeoTracking(updateAddress).startTracking();
    }
  }

  updateAddress(GPS gps) {
    _addr = gps.address.address();
    setState(() {});
  }

  void _onItemTapped(int index) {
    tapped++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Title',
        home: Scaffold(
            appBar: AppBar(
              leading: const Icon(Icons.navigation),
              title: const Text(
                'text',
              ),
              toolbarHeight: 60,
            ),
            body: Center(child: Text('$tapped Address: $_addr ')),
            bottomNavigationBar:
                BottomNavigationBar(items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Start'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.list), label: 'Arbeiten'),
            ], onTap: _onItemTapped, currentIndex: 0)));
  }
}
