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

import 'package:flutter/material.dart';
import 'package:chaostours/view/app_init.dart';
import 'package:chaostours/view/widget_live_tracking.dart';
import 'package:chaostours/view/widget_trackpoints.dart';
import 'package:chaostours/view/widget_logger_page.dart';
import 'package:chaostours/view/widget_permissions_page.dart';
import 'package:chaostours/view/widget_edit_trackpoint.dart';
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

/// use value instead of name to get the right
enum AppRoutes {
  /// appStart
  // trackpoints
  liveTracking('/'),
  trackpoints('/trackpoints'),
  editTrackPoint('/editTrackPoint'),
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

  static get routes {
    return <String, Widget Function(BuildContext)>{
      // home routes
      //AppRoutes.home.route: (context) => const WidgetTrackingPage(),

      /// add/edit items routes
      // trackpoint
      AppRoutes.liveTracking.route: (context) => const WidgetTrackingPage(),
      AppRoutes.trackpoints.route: (context) => const WidgetTrackPoints(),
      AppRoutes.editTrackPoint.route: (context) => const WidgetEditTrackPoint(),
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
      AppRoutes.selectCalendar.route: (context) => const WidgetManageCalendar(),
      // osm
      AppRoutes.osm.route: (context) => const WidgetOsm(),

      /// system config routes
      AppRoutes.appInit.route: (context) => const AppInit(),
      AppRoutes.logger.route: (context) => const WidgetLoggerPage(),
      AppRoutes.permissions.route: (context) => const WidgetPermissionsPage(),
      AppRoutes.importExport.route: (context) => const WidgetImportExport(),
      AppRoutes.appSettings.route: (context) => const WidgetAppSettings(),
      AppRoutes.backgroundGps.route: (context) =>
          const WidgetManageBackgroundGps()
    };
  }
}
