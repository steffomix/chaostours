/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the License);
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an AS IS BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/calendar.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/tracking.dart';
import 'package:geolocator/geolocator.dart';

class TypeAdapter {
  static final Logger logger = Logger.logger<TypeAdapter>();

  /// intList
  static List<String> serializeIntList(List<int> list) =>
      list.map((e) => e.toString()).toList();
  static List<int> deserializeIntList(List<String>? s) =>
      s == null ? [] : s.map((e) => int.parse(e)).toList();

  /// DateTime
  static String serializeDateTime(DateTime dateTime) =>
      dateTime.toIso8601String();
  static DateTime? deserializeDateTime(String? time) =>
      time == null ? null : DateTime.parse(time);

  /// Duration
  static int serializeDuration(Duration duration) => duration.inSeconds;
  static Duration? deserializeDuration(int? seconds) =>
      seconds == null ? null : Duration(seconds: seconds);

  /// CalendarEventId
  static List<String> serializeCalendarEventId(List<CalendarEventId> ids) =>
      ids.map((e) => e.toString()).toList();
  static List<CalendarEventId> deserializeCalendarEventId(List<String>? ids) =>
      ids == null ? [] : ids.map((s) => CalendarEventId.toObject(s)).toList();

  /// gps list
  static List<String> serializeGpsList(List<GPS> gpsList) {
    return gpsList.map((e) => e.toString()).toList();
  }

  static List<GPS>? deserializeGpsList(List<String>? list) {
    return list == null ? [] : list.map((e) => GPS.toObject(e)).toList();
  }

  /// DateTime list
  static List<String> serializeDateTimeList(List<DateTime> gpsList) {
    return gpsList.map((e) => e.toIso8601String()).toList();
  }

  static List<DateTime>? deserializeDateTimeList(List<String>? list) {
    return list == null ? [] : list.map((e) => DateTime.parse(e)).toList();
  }

  /// GPS
  static String serializeGps(GPS gps) => gps.toString();
  static GPS? deserializeGps(String? gps) =>
      gps == null ? null : GPS.toObject(gps);

  /// trackingstatus
  static String serializeTrackingStatus(TrackingStatus t) {
    return t.name;
  }

  static TrackingStatus? deserializeTrackingStatus(String? s) {
    return s == null ? null : TrackingStatus.values.byName(s);
  }

  // ModelTrackPoint
  static String serializeModelTrackPoint(ModelTrackPoint tp) =>
      Model.toJson(tp.toMap());
  static ModelTrackPoint? deserializeModelTrackPoint(String? tp) =>
      tp == null ? null : ModelTrackPoint.fromMap(Model.fromJson(tp));

  /// List ModelAlias
  static List<String> serializeModelAliasList(List<ModelAlias> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelAlias>? deserializeModelAliasList(List<String>? list) =>
      list == null
          ? []
          : list.map((e) => ModelAlias.fromMap(Model.fromJson(e))).toList();

  /// List ModelUser
  static List<String> serializeModelUserList(List<ModelUser> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelUser>? deserializeModelUserList(List<String>? list) =>
      list == null
          ? []
          : list.map((e) => ModelUser.fromMap(Model.fromJson(e))).toList();

  /// List ModelTask
  static List<String> serializeModelTaskList(List<ModelTask> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelTask>? deserializeModelTaskList(List<String>? list) =>
      list == null
          ? []
          : list.map((e) => ModelTask.fromMap(Model.fromJson(e))).toList();

  /// List ModelTrackPoint
  static List<String> serializeModelTrackPointList(
          List<ModelTrackPoint> tpList) =>
      tpList.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelTrackPoint>? deserializeModelTrackPointList(
          List<String>? list) =>
      list == null
          ? []
          : list
              .map((e) => ModelTrackPoint.fromMap(Model.fromJson(e)))
              .toList();

  /// OSMLookup
  static String serializeOsmLookup(OsmLookupConditions o) => o.name;
  static OsmLookupConditions? deserializeOsmLookup(String? osm) => osm == null
      ? OsmLookupConditions.never
      : OsmLookupConditions.values.byName(osm);

  /// OSMLookup
  static String serializeLocationAccuracy(LocationAccuracy o) => o.name;
  static LocationAccuracy? deserializeLocationAccuracy(String? acc) =>
      acc == null ? LocationAccuracy.best : LocationAccuracy.values.byName(acc);

  /// OSMWeekdays
  static String serializeWeekdays(Weekdays o) => o.name;
  static Weekdays? deserializeWeekdays(String? osm) =>
      osm == null ? Weekdays.mondayFirst : Weekdays.values.byName(osm);
}
