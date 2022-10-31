import 'package:flutter/material.dart';
import 'randomWord.dart';
import 'randomWordList.dart';
// container
import 'container/topBar.dart';
import 'container/bottomBar.dart';
//misc
import 'settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Settings.appName,
      home: Scaffold(
        appBar: AppBar(
            title: const Text('appName'),
            backgroundColor: Color.fromARGB(255, 32, 156, 165),
            toolbarHeight: 30),
        body: const Center(
          child: RandomWords(),
        ),
        bottomNavigationBar: const BottomBar(),
      ),
    );
  }
}
