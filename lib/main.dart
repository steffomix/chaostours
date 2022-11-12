import 'dart:math';

import 'package:flutter/material.dart';
import 'geoCoding.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

//double _lat = 52.3366473695;
double _lat = 52.3367;
double _lon = 9.21645353535;

class _AppState extends State<App> {
  final geo = Geo();
  String _addr = '';
  int _requested = 0;

  void _onItemTapped(int index) {
    geo.lookup(_lat + Random().nextDouble(), _lon + Random().nextDouble());
    _requested++;
    var addr = geo.address.address();
    var lastAddr = geo.lastAddress.address();
    _addr = '$addr \n $lastAddr';
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
            body: Center(child: Text('$_requested Address: $_addr ')),
            bottomNavigationBar:
                BottomNavigationBar(items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Start'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.list), label: 'Arbeiten'),
            ], onTap: _onItemTapped, currentIndex: 0)));
  }
}
