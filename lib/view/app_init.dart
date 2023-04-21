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
  List<String> _msg = [];
  AppRoutes? route;

  @override
  void initState() {
    route = null;
    _msg = [];
    super.initState();
    appStart();
  }

  set msg(String msg) {
    logger.error(msg, StackTrace.current);
    _msg.add(msg);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> appStart() async {}

  @override
  Widget build(BuildContext context) {
    if (route != null) {
      Future.delayed(const Duration(seconds: 2),
          () => Navigator.pushNamed(context, route!.route));
    }

    return AppWidgets.scaffold(context,
        body: AppWidgets.loading(_msg.join('\n\n')));
  }
}
