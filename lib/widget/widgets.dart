import 'package:flutter/material.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/widget/widget_drawer.dart';
import 'package:chaostours/widget/widget_bottom_navbar.dart';
import 'package:chaostours/page/widget_tracking_page.dart';
import 'package:chaostours/page/widget_logger_page.dart';
import 'package:chaostours/page/widget_permissions_page.dart';
import 'package:chaostours/page/widget_edit_trackpoint_tasks_page.dart';

/// use value instead of name to get the right
enum AppRoutes {
  home('/'),
  logger('/logger'),
  permissions('/permissions'),
  editTrackingTasks('/editTrackingTasks'),
  createTask('/createTask'),
  editTasks('/editTasks'),
  createAlias('/createAlias'),
  editAlias('/editAlias');

  final String route;
  const AppRoutes(this.route);
}

class Widgets {
  static final Logger logger = Logger.logger<Widgets>();

  static Widget materialApp(BuildContext context) {
    return MaterialApp(
      title: 'Chaos Tours',
      initialRoute: AppRoutes.home.route,
      routes: {
        AppRoutes.home.route: (context) => const WidgetTrackingPage(),
        AppRoutes.logger.route: (context) => const WidgetLoggerPage(),
        AppRoutes.permissions.route: (context) => const WidgetPermissionsPage(),
        AppRoutes.editTrackingTasks.route: (context) =>
            const WidgetEditTrackpointTasks()
      },
      theme: ThemeData(
        primarySwatch: Colors.amber,
        primaryColor: const Color(0xFF4b830d),
        canvasColor: const Color(0xFFDDDDDD),
      ),
      //home: const WidgetTrackingPage(),
    );
  }

  static Widget scaffold(BuildContext context, Widget body) {
    return Scaffold(
      appBar: Widgets.appBar(context),
      drawer: const WidgetDrawer(),
      body: body,
      bottomNavigationBar: const WidgetBottomNavBar(),
    );
  }

  static AppBar appBar(BuildContext context) {
    return AppBar(title: const Text('ChaosTours'));
  }
}
