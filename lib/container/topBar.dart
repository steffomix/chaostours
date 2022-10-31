import 'package:flutter/material.dart';

class TopBar {
  AppBar bar() {
    return AppBar(
        title: const Text('appName'),
        backgroundColor: Color.fromARGB(255, 32, 156, 165),
        toolbarHeight: 30);
  }
}
