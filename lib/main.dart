import 'package:flutter/material.dart';
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/logger.dart';
import 'page/widget_tracking_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  Logger.logLevel = LogLevel.verbose;
  AppLoader.preload();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generated App',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        primaryColor: const Color(0xFF4b830d),
        canvasColor: const Color(0xFFDDDDDD),
      ),
      home: const WidgetTrackingPage(),
    );
  }
}
