import 'package:flutter/material.dart';

///
import 'package:chaostours/view/app_widgets.dart';
import 'package:chaostours/logger.dart';

class AppInit extends StatefulWidget {
  const AppInit({super.key});

  @override
  State<AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<AppInit> {
  static final Logger logger = Logger.logger<AppInit>();

  @override
  void initState() {
    super.initState();
  }

  Future<void> appStart() async {}

  @override
  Widget build(BuildContext context) {
    return AppWidgets.scaffold(context, body: AppWidgets.loading(''));
  }
}
