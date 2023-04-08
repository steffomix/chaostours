import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
//
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.logLevel = LogLevel.verbose;
  await Hive.initFlutter();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppWidgets.materialApp(context);
  }
}
