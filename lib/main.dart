//import 'package:package_info_plus/package_info_plus.dart';
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
/*
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF2196f3),
        accentColor: const Color(0xFF2196f3),
        canvasColor: const Color(0xFFfafafa),
      ),


      <resources>
  <color name="primaryColor">#7cb342</color>
  <color name="primaryLightColor">#aee571</color>
  <color name="primaryDarkColor">#4b830d</color>
  <color name="secondaryColor">#ffb300</color>
  <color name="secondaryLightColor">#ffe54c</color>
  <color name="secondaryDarkColor">#c68400</color>
  <color name="primaryTextColor">#000000</color>
  <color name="secondaryTextColor">#000000</color>
</resources>
*/