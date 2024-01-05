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
import 'package:chaostours/view/boot.dart';
//
import 'package:chaostours/view/system/widget_permissions_page.dart';
import 'package:chaostours/view/system/widget_import_export.dart';
import 'package:chaostours/view/system/widget_app_settings.dart';
import 'package:chaostours/view/system/widget_database_explorer.dart';
//
import 'package:chaostours/view/alias/widget_alias_list.dart';
import 'package:chaostours/view/alias/widget_alias_edit.dart';
import 'package:chaostours/view/alias/widget_alias__group_edit.dart';
import 'package:chaostours/view/alias/widget_alias__group_list.dart';
import 'package:chaostours/view/alias/widget_aliases_from_alias__group_list.dart';
import 'package:chaostours/view/alias/widget_alias__groups_from_alias_list.dart';
import 'package:chaostours/view/alias/widget_edit_alias_osm.dart';
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
import 'package:chaostours/view/trackpoint/widget_trackpoints_from_alias_list.dart';
import 'package:chaostours/view/trackpoint/widget_edit_trackpoint.dart';
//
import 'package:chaostours/view/widget_manage_calendar.dart';

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
  trackpointsFromAliasList,

  // alias
  listAlias,
  editAlias,

  // alias group
  listAliasGroup,
  editAliasGroup,
  listAliasGroupsFromAlias,
  listAliasesFromAliasGroup,

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
  selectCalendar,
  osm;

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

      // alias
      AppRoutes.listAlias.route: (context) => const WidgetAliasList(),
      AppRoutes.editAlias.route: (context) => const WidgetAliasEdit(),

      // alias group
      AppRoutes.listAliasGroup.route: (context) => const WidgetAliasGroupList(),
      AppRoutes.editAliasGroup.route: (context) => const WidgetAliasGroupEdit(),
      AppRoutes.listAliasGroupsFromAlias.route: (context) =>
          const WidgetAliasGroupsFromAliasList(),
      AppRoutes.listAliasesFromAliasGroup.route: (context) =>
          const WidgetAliasesFromAliasGroupList(),

      // trackPoint events
      AppRoutes.selectCalendar.route: (context) => const WidgetManageCalendar(),
      AppRoutes.trackpointsFromAliasList.route: (context) =>
          const WidgetAliasTrackpoint(),
      // osm
      AppRoutes.osm.route: (context) => const WidgetOsm(),
    };
  }
}
