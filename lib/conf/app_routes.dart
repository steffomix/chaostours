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
import 'package:chaostours/view/system/boot.dart';
//
import 'package:chaostours/view/system/widget_permissions_page.dart';
import 'package:chaostours/view/system/widget_import_export.dart';
import 'package:chaostours/view/system/widget_app_settings.dart';
import 'package:chaostours/view/system/widget_database_explorer.dart';
//
import 'package:chaostours/view/location/widget_location_list.dart';
import 'package:chaostours/view/location/widget_location_edit.dart';
import 'package:chaostours/view/location/widget_location__group_edit.dart';
import 'package:chaostours/view/location/widget_location__group_list.dart';
import 'package:chaostours/view/location/widget_locations_from_location__group_list.dart';
import 'package:chaostours/view/location/widget_location__groups_from_location_list.dart';
import 'package:chaostours/view/location/widget_edit_location_osm.dart';
//
import 'package:chaostours/view/user/widget_user_list.dart';
import 'package:chaostours/view/user/widget_user_edit.dart';
import 'package:chaostours/view/user/widget_user__group_edit.dart';
import 'package:chaostours/view/user/widget_user__group_list.dart';
import 'package:chaostours/view/user/widget_users_from_user__group_list.dart';
import 'package:chaostours/view/user/widget_user__groups_from_user_list.dart';
//
import 'package:chaostours/view/task/widget_task_list.dart';
import 'package:chaostours/view/task/widget_task_edit.dart';
import 'package:chaostours/view/task/widget_task__group_edit.dart';
import 'package:chaostours/view/task/widget_task__group_list.dart';
import 'package:chaostours/view/task/widget_tasks_from_task__group_list.dart';
import 'package:chaostours/view/task/widget_task__groups_from_task_list.dart';
//
import 'package:chaostours/view/trackpoint/widget_live_tracking.dart';
import 'package:chaostours/view/trackpoint/widget_trackpoint_list.dart';
import 'package:chaostours/view/trackpoint/widget_edit_trackpoint.dart';
//
import 'package:chaostours/view/system/widget_color_scheme_picker.dart';
//
import 'package:chaostours/view/calendar/widget_manage_calendar.dart';
//
import 'package:chaostours/view/calendar/calendar.dart';

enum AppRoutes {
  // system
  welcome,
  permissions,
  importExport,
  databaseExplorer,
  appSettings,

  // trackpoints
  liveTracking,
  listTrackpoints,
  editTrackPoint,

  // location
  listLocation,
  editLocation,

  // allocationias group
  listLocationGroup,
  editLocationGroup,
  listLocationGroupsFromLocation,
  listLocationsFromLocationGroup,

  // task
  listTask,
  editTask,

  // task group
  listTaskGroup,
  editTaskGroup,
  listTaskGroupsFromTask,
  listTasksFromTaskGroup,

  // user
  listUser,
  editUser,

  // userGroup
  listUserGroup,
  editUserGroup,
  listUserGroupsFromUser,
  listUsersFromUserGroup,

  // misc
  colorSchemePicker,
  selectCalendar,
  osm,

  // calendar
  calendar;

  String get route => name.toLowerCase();

  static Future<void> navigate(BuildContext context, AppRoutes route,
      [Object? arguments]) async {
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.liveTracking.route, (Route<dynamic> route) => false);
    if (route != AppRoutes.liveTracking) {
      Navigator.pushNamed(context, route.route, arguments: arguments);
    }
  }

  static Map<String, Widget Function(BuildContext)>? _routes;
  static get routes {
    return _routes ??= <String, Widget Function(BuildContext)>{
      /// initial and preloader route
      AppRoutes.welcome.route: (context) => const Welcome(),

      /// system config routes
      AppRoutes.permissions.route: (context) => const WidgetPermissionsPage(),
      AppRoutes.importExport.route: (context) => const WidgetImportExport(),
      AppRoutes.databaseExplorer.route: (context) =>
          const WidgetDatabaseExplorer(),
      AppRoutes.appSettings.route: (context) => const WidgetAppSettings(),

      // trackpoint
      AppRoutes.liveTracking.route: (context) => const WidgetTrackingPage(),
      AppRoutes.listTrackpoints.route: (context) => const WidgetTrackPoints(),
      AppRoutes.editTrackPoint.route: (context) => const WidgetEditTrackPoint(),

      // user
      AppRoutes.listUser.route: (context) => const WidgetUserList(),
      AppRoutes.editUser.route: (context) => const WidgetUserEdit(),

      // user group
      AppRoutes.listUserGroup.route: (context) => const WidgetUserGroupList(),
      AppRoutes.editUserGroup.route: (context) => const WidgetUserGroupEdit(),
      AppRoutes.listUserGroupsFromUser.route: (context) =>
          const WidgetUserGroupsFromUserList(),
      AppRoutes.listUsersFromUserGroup.route: (context) =>
          const WidgetUsersFromUserGroupList(),

      // task
      AppRoutes.listTask.route: (context) => const WidgetTaskList(),
      AppRoutes.editTask.route: (context) => const WidgetTaskEdit(),

      // task group
      AppRoutes.listTaskGroup.route: (context) => const WidgetTaskGroupList(),
      AppRoutes.editTaskGroup.route: (context) => const WidgetTaskGroupEdit(),
      AppRoutes.listTaskGroupsFromTask.route: (context) =>
          const WidgetTaskGroupsFromTaskList(),
      AppRoutes.listTasksFromTaskGroup.route: (context) =>
          const WidgetTasksFromTaskGroupList(),

      // location
      AppRoutes.listLocation.route: (context) => const WidgetLocationList(),
      AppRoutes.editLocation.route: (context) => const WidgetLocationEdit(),

      // location group
      AppRoutes.listLocationGroup.route: (context) =>
          const WidgetLocationGroupList(),
      AppRoutes.editLocationGroup.route: (context) =>
          const WidgetLocationGroupEdit(),
      AppRoutes.listLocationGroupsFromLocation.route: (context) =>
          const WidgetLocationGroupsFromLocationList(),
      AppRoutes.listLocationsFromLocationGroup.route: (context) =>
          const WidgetLocationsFromLocationGroupList(),

      // color scheme
      AppRoutes.colorSchemePicker.route: (context) =>
          const WidgetColorSchemePicker(),
      // trackPoint events
      AppRoutes.selectCalendar.route: (context) => const WidgetManageCalendar(),
      // osm
      AppRoutes.osm.route: (context) => const WidgetOsm(),

      // calendar
      AppRoutes.calendar.route: (context) => const WidgetCalendar(),
    };
  }
}
