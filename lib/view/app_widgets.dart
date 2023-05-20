/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/model/model_trackpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:fluttertoast/fluttertoast.dart';

///
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/cache.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/view/app_init.dart';
import 'package:chaostours/view/app_colors.dart';
import 'package:chaostours/view/widget_live_tracking.dart';
import 'package:chaostours/view/widget_logger_page.dart';
import 'package:chaostours/view/widget_permissions_page.dart';
import 'package:chaostours/view/widget_edit_trackpoint.dart';
import 'package:chaostours/view/widget_edit_pending_trackpoint.dart';
import 'package:chaostours/view/widget_user_list.dart';
import 'package:chaostours/view/widget_task_list.dart';
import 'package:chaostours/view/widget_alias_list.dart';
import 'package:chaostours/view/widget_task_edit.dart';
import 'package:chaostours/view/widget_user_edit.dart';
import 'package:chaostours/view/widget_alias_edit.dart';
import 'package:chaostours/view/widget_alias_trackpoint_list.dart';
import 'package:chaostours/view/widget_osm.dart';
import 'package:chaostours/view/widget_import_export.dart';
import 'package:chaostours/view/widget_app_settings.dart';
import 'package:chaostours/view/widget_manage_background_gps.dart';
import 'package:chaostours/view/widget_manage_calendar.dart';

enum AppColorScheme {
  bright(mangoMojitoLight),
  dark(mangoMojitoLight);

  final ColorScheme scheme;

  const AppColorScheme(this.scheme);
}

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
  /// appStart
  //home('/'),
  // live
  liveTracking('/'),
  editTrackPoint('/editTrackPoint'),
  editPendingTrackPoint('/editPendingTrackPoint'),
  // task
  listTasks('/listTasks'),
  editTasks('/listTasks/editTasks'),
  createTask('/listTasks/createTask'),
  // alias
  listAlias('/listAlias'),
  listAliasTrackpoints('/listAlias/listAliasTrackpoints'),
  editAlias('/listAlias/listAliasTrackpoints/editAlias'),
  // user
  listUsers('/listUsers'),
  editUser('/listUsers/editUser'),
  createUser('/listUsers/createUser'),
  // trackpoint events
  selectCalendar('/selectCalendar'),
  // osm
  osm('/osm'),
  // system
  appInit('/appInit'),
  logger('/logger'),
  permissions('/permissions'),
  importExport('/importexport'),
  appSettings('/appsettings'),
  backgroundGps('/manageBackgroundGps');

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
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        //themeMode: ThemeMode.system,
        title: 'Chaos Tours',
        initialRoute: AppRoutes.liveTracking.route,
        routes: {
          // home routes
          //AppRoutes.home.route: (context) => const WidgetTrackingPage(),

          /// add/edit items routes
          // trackpoint
          AppRoutes.liveTracking.route: (context) => const WidgetTrackingPage(),
          AppRoutes.editTrackPoint.route: (context) =>
              const WidgetEditTrackPoint(),
          AppRoutes.editPendingTrackPoint.route: (context) =>
              const WidgetEditPendingTrackPoint(),
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
          // trackPoint events
          AppRoutes.selectCalendar.route: (context) =>
              const WidgetManageCalendar(),
          // osm
          AppRoutes.osm.route: (context) => const WidgetOsm(),

          /// system config routes
          AppRoutes.appInit.route: (context) => const AppInit(),
          AppRoutes.logger.route: (context) => const WidgetLoggerPage(),
          AppRoutes.permissions.route: (context) =>
              const WidgetPermissionsPage(),
          AppRoutes.importExport.route: (context) => const WidgetImportExport(),
          AppRoutes.appSettings.route: (context) => const WidgetAppSettings(),
          AppRoutes.backgroundGps.route: (context) =>
              const WidgetManageBackgroundGps()
        },
        theme: ThemeData(colorScheme: AppColorScheme.bright.scheme));
  }

  static Future<void> navigate(BuildContext context, AppRoutes route,
      [Object? arguments]) async {
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

  static Widget loading(String info) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      LoadingAnimationWidget.staggeredDotsWave(
          color: AppColors.black.color, size: 30),
      Text(info)
    ]));
  }

  static Future<T?> dialog<T>(
      {required BuildContext context,
      required List<Widget> contents,
      required List<Widget> buttons}) {
    var dialog = showDialog<T>(
        context: context,
        builder: (context) {
          return Dialog(
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ...contents,
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: buttons)
                  ])));
        });

    return dialog;
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
                    AppWidgets.navigate(context, AppRoutes.liveTracking);
                  },
                  child: const Text('Tracking')),
              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nManage Hintergrund GPS'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.backgroundGps);
                  },
                  child: const Text('Background GPS')),

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
                  child: const Text('Arbeiten')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.listAlias);
                  },
                  child: const Text('Orte (Alias)')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nEvents'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.selectCalendar);
                  },
                  child: const Text('Calendar')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nEinstellungen'))),

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
                    AppWidgets.navigate(context, AppRoutes.permissions, 1);
                  },
                  child: const Text('Android Permissions')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.logger);
                  },
                  child: const Text('App Logger')),

              SizedBox(
                  height: boxHeight,
                  child: const Center(child: Text('\nDatenbank'))),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppWidgets.navigate(context, AppRoutes.importExport);
                  },
                  child: const Text('Export / Import')),

              ///
              ElevatedButton(
                  onPressed: () {
                    AppLoader.loadAssetDatabase();
                  },
                  child: const Text('Lade Built-In Data')),

              ///
              ElevatedButton(
                  onPressed: () async {
                    await Cache.setValue<List<ModelTrackPoint>>(
                        CacheKeys.tableModelTrackpoint, []);
                    await ModelTrackPoint.open();
                    Fluttertoast.showToast(msg: "All TrackPoints deleted");
                  },
                  child: const Text('Lösche alle Haltepunkte')),
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
