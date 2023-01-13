import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/recource_loader.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';

// android native code

void main() async {
  // Thanks for: https://stackoverflow.com/a/69481863
  // add cert for https requests you can download here:
  // https://letsencrypt.org/certs/lets-encrypt-r3.pem
  WidgetsFlutterBinding.ensureInitialized();

  // set loglevel
  Logger.logLevel = LogLevel.log;

  // preload recources
/*
  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Globals.version = packageInfo.version;
  } catch (e) {
    logger.logError(e);
  }
*/
  // start frontend
  runApp(Globals.app);
  Future.delayed(const Duration(seconds: 2), AppLoader.preload);
}
