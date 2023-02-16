import 'package:flutter/material.dart';

///
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:chaostours/widget/widget_drawer.dart';
import 'package:chaostours/page/widget_tracking_page.dart';
import 'package:chaostours/page/widget_logger_page.dart';
import 'package:chaostours/page/widget_permissions_page.dart';
import 'package:chaostours/page/widget_edit_trackpoint_tasks_page.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/page/widget_user_list.dart';
import 'package:chaostours/page/widget_task_list.dart';
import 'package:chaostours/page/widget_alias_list.dart';
import 'package:chaostours/page/widget_task_edit.dart';
import 'package:chaostours/page/widget_user_edit.dart';
import 'package:chaostours/page/widget_alias_edit.dart';
import 'package:chaostours/page/widget_osm.dart';

/// use value instead of name to get the right
enum AppRoutes {
  home('/'),
  logger('/logger'),
  permissions('/permissions'),
  editTrackingTasks('/editTrackingTasks'),
  //
  listTasks('/listTasks'),
  editTasks('/listTasks/editTasks'),
  createTask('/listTasks/editTasks/createTask'),
  //
  listAlias('/listAlias'),
  editAlias('/listAlias/editAlias'),
  createAlias('/listAlias/editAlias/createAlias'),
  //
  listUsers('/listUsers'),
  editUser('/listUsers/editUser'),
  createUser('/listUsers/editUser/createUser'),
  //
  osm('/osm');

  final String route;
  const AppRoutes(this.route);
}

class NavigatorArguments {
  int id = 0;
  Map<String, String> params = {};
}

class AppWidgets {
  static final Logger logger = Logger.logger<AppWidgets>();

  static Widget materialApp(BuildContext context) {
    return MaterialApp(
      title: 'Chaos Tours',
      initialRoute: AppRoutes.home.route,
      routes: {
        // home routes
        AppRoutes.home.route: (context) => const WidgetTrackingPage(),

        /// system config routes
        AppRoutes.logger.route: (context) => const WidgetLoggerPage(),
        AppRoutes.permissions.route: (context) => const WidgetPermissionsPage(),

        /// add/edit items routes
        // trackpoint
        AppRoutes.editTrackingTasks.route: (context) =>
            const WidgetEditTrackpointTasks(),
        // user
        AppRoutes.listUsers.route: (context) => const WidgetUserList(),
        AppRoutes.editUser.route: (context) => const WidgetUserEdit(),
        // task
        AppRoutes.listTasks.route: (context) => const WidgetTaskList(),
        AppRoutes.editTasks.route: (context) => const WidgetTaskEdit(),
        // alias
        AppRoutes.listAlias.route: (context) => const WidgetAliasList(),
        AppRoutes.editAlias.route: (context) => const WidgetAliasEdit(),
        // osm
        AppRoutes.osm.route: (context) => const WidgetOsm(),
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

  static String timeInfo(DateTime timeStart, DateTime timeEnd) {
    var day = '${Globals.weekDays[timeStart.weekday]}. den'
        ' ${timeStart.day}.${timeStart.month}.${timeStart.year}';
    String duration = util.timeElapsed(timeStart, timeEnd, false);
    return '$day, ${timeStart.hour}:${timeStart.minute} - ${timeEnd.hour}:${timeEnd.minute}\n ($duration)';
  }
}
