//import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.logLevel = LogLevel.log;
  await Future.delayed(const Duration(seconds: 1), AppLoader.preload);
  runApp(Globals.app);
}
