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

/// use value instead of name to get the right
enum AppRoutes {
  /// appStart
  //home('/'),
  // live
  liveTracking('/'),
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
}
