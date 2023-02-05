import 'package:flutter/material.dart';
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/logger.dart';
import 'widget/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.logLevel = LogLevel.verbose;
  runApp(const MyApp());
  AppLoader.preload();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgets.materialApp(context);
  }
}
