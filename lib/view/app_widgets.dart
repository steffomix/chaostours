import 'package:chaostours/model/model_alias.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

///
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/logger.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/background_process/tracking.dart';
import 'package:chaostours/view/widget_tracking_page.dart';
import 'package:chaostours/view/widget_logger_page.dart';
import 'package:chaostours/view/widget_permissions_page.dart';
import 'package:chaostours/view/widget_edit_trackpoint_tasks_page.dart';
import 'package:chaostours/view/widget_user_list.dart';
import 'package:chaostours/view/widget_task_list.dart';
import 'package:chaostours/view/widget_alias_list.dart';
import 'package:chaostours/view/widget_task_edit.dart';
import 'package:chaostours/view/widget_user_edit.dart';
import 'package:chaostours/view/widget_alias_edit.dart';
import 'package:chaostours/view/widget_alias_trackpoint_list.dart';
import 'package:chaostours/view/widget_osm.dart';
import 'package:chaostours/view/widget_storage_settings.dart';
import 'package:chaostours/view/widget_app_settings.dart';

enum AppColors {
  /// theme colors
  yellow(Colors.amber),
  green(Color(0xFF4b830d)),

  /// icons
  black(Color.fromARGB(255, 51, 51, 51)),

  ///Background
  white(Color(0xFFDDDDDD)),

  /// transparent background
  white54(Colors.white54),

  /// alias colors
  aliasRestricted(Colors.red),
  aliasPrivate(Colors.blue),
  aliasPubplic(Colors.green);

  static Color aliasStatusColor(AliasStatus status) {
    Color color;
    if (status == AliasStatus.privat) {
      color = AppColors.aliasPrivate.color;
    } else if (status == AliasStatus.restricted) {
      color = AppColors.aliasRestricted.color;
    } else {
      color = AppColors.aliasPubplic.color;
    }
    return color;
  }

  final Color color;
  const AppColors(this.color);
}

/// use value instead of name to get the right
enum AppRoutes {
  home('/'),
  // system
  logger('/logger'),
  permissions('/permissions'),
  storageSettings('/storagesettings'),
  appSettings('/appsettings'),
  // live
  editTrackingTasks('/editTrackingTasks'),
  // task
  listTasks('/listTasks'),
  editTasks('/listTasks/editTasks'),
  createTask('/listTasks/editTasks/createTask'),
  // alias
  listAlias('/listAlias'),
  editAlias('/listAlias/editAlias'),
  listAliasTrackpoints('/listAlias/editAlias/listAliasTrackpoints'),
  // user
  listUsers('/listUsers'),
  editUser('/listUsers/editUser'),
  createUser('/listUsers/editUser/createUser'),
  // osm
  osm('/osm');

  final String route;
  const AppRoutes(this.route);
}

///
///
///
///
///
///
class AppWidgets {
  static final Logger logger = Logger.logger<AppWidgets>();

  static Widget materialApp(BuildContext context) {
    String homeRoute = AppRoutes.home.route;
    return MaterialApp(
      title: 'Chaos Tours',
      initialRoute: homeRoute,
      routes: {
        // home routes
        AppRoutes.home.route: (context) => const WidgetTrackingPage(),

        /// system config routes
        AppRoutes.logger.route: (context) => const WidgetLoggerPage(),
        AppRoutes.permissions.route: (context) => const WidgetPermissionsPage(),
        AppRoutes.storageSettings.route: (context) =>
            const WidgetStorageSettings(),
        AppRoutes.appSettings.route: (context) => const WidgetAppSettings(),

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
        AppRoutes.listAliasTrackpoints.route: (context) =>
            const WidgetAliasTrackpoint(),
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

  static void navigate(BuildContext context, AppRoutes route,
      [Object? arguments]) {
    while (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    Navigator.pushNamed(context, route.route, arguments: arguments);
  }

  static Widget scaffold(BuildContext context,
      {required Widget body,
      BottomNavigationBar? navBar,
      AppBar? customAppBar}) {
    return Scaffold(
      appBar: appBar(context),
      drawer: const WidgetDrawer(),
      body: body,
      bottomNavigationBar: navBar,
    );
  }

  static AppBar appBar(BuildContext context) {
    return AppBar(title: const Text('ChaosTours'));
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

  static Widget loading({double? size, Color? color}) {
    return LoadingAnimationWidget.staggeredDotsWave(
        color: color ?? AppColors.black.color, size: size ?? 30);
  }
}

///
///
///
///
///
///

class WidgetDrawer extends StatefulWidget {
  const WidgetDrawer({super.key});

  @override
  State<WidgetDrawer> createState() => _WidgetDrawer();
}

class _WidgetDrawer extends State<WidgetDrawer> {
  @override
  Widget build(BuildContext context) {
    var divider = AppWidgets.divider();
    double boxHeight = 45;
    return Drawer(
        child: Container(
            padding: const EdgeInsets.all(20),
            child: ListView(padding: EdgeInsets.zero, children: [
              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nLive Tracking'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.home);
                  },
                  child: const Text('Tracking')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nAssets'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.listUsers);
                  },
                  child: const Text('Personal')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.listTasks);
                  },
                  child: const Text('Aufgaben')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.listAlias);
                  },
                  child: const Text('Orte (Alias)')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nEinstellungen'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.storageSettings);
                  },
                  child: const Text('Speicherort')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.appSettings);
                  },
                  child: const Text('Einstellungen')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nSystem'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.permissions);
                  },
                  child: const Text('Android Permissions')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.logger);
                  },
                  child: const Text('App Logger'))
            ])));
  }
}

///
///
///
///
///
///

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSizeRenderObject extends RenderProxyBox {
  Size? oldSize;
  OnWidgetSizeChange onChange;

  MeasureSizeRenderObject(this.onChange);

  @override
  void performLayout() {
    super.performLayout();

    Size newSize = child!.size;
    if (oldSize == newSize) return;

    oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}

class WidgetSizeListener extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onChange;

  const WidgetSizeListener({
    Key? key,
    required this.onChange,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant MeasureSizeRenderObject renderObject) {
    renderObject.onChange = onChange;
  }
}
