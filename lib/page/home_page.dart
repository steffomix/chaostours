import 'package:flutter/material.dart';
//
import 'package:chaostours/page/widget_tracking_page.dart';
import 'package:chaostours/logger.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  // app main pane

  @override
  State<HomePage> createState() => _HomePageState();
}

///
///
///
class _HomePageState extends State<HomePage> {
  static final Logger logger = Logger.logger<HomePage>();
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: WidgetTrackingPage());
  }
}
