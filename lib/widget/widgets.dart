import 'package:flutter/material.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/widget/widget_drawer.dart';
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

class AppWidgets {
  static final Logger logger = Logger.logger<AppWidgets>();

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

  static Widget scaffold(BuildContext context,
      {required Widget body, BottomNavigationBar? navBar, AppBar? appBar}) {
    return Scaffold(
      appBar: appBar ?? AppWidgets.appBar(context),
      drawer: const WidgetDrawer(),
      body: body,
      bottomNavigationBar: navBar ?? bottomNavBar(context),
    );
  }

  static AppBar appBar(BuildContext context) {
    return AppBar(title: const Text('ChaosTours'));
  }

  static BottomNavigationBar bottomNavBar(context) {
    return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.keyboard_arrow_left), label: 'x'),
          BottomNavigationBarItem(icon: Icon(Icons.location_city), label: 'x'),
          BottomNavigationBarItem(
              icon: Icon(Icons.keyboard_arrow_right), label: 'x'),
        ],
        onTap: (int id) {
          logger.log('BottomNavBar tapped but no method connected');
          //eventBusTapBottomNavBarIcon.fire(Tapped(id));
        });
  }

  static Widget divider({Color color = Colors.blueGrey}) {
    return Divider(thickness: 1, indent: 10, endIndent: 10, color: color);
  }
}
