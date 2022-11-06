import 'package:flutter/material.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  void _onItemTapped(int index) {
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
            body: Column(children: <Widget>[
              Row(children: const <Widget>[Text('test'), Text('t2')])
            ]),
            bottomNavigationBar:
                BottomNavigationBar(items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Start'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.list), label: 'Arbeiten'),
            ], onTap: _onItemTapped, currentIndex: 1)));
  }
}
