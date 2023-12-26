/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the License);
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    htvalue://www.apache.org/licenses/LICENSE-2.0

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
import 'package:chaostours/tracking.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:geolocator/geolocator.dart';

/* 
import 'package:chaostours/model/model.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_user.dart'; 
*/

class TypeAdapter {
  static final Logger logger = Logger.logger<TypeAdapter>();

  /// intList
  static List<String> serializeIntList(List<int> value) =>
      value.map((e) => e.toString()).toList();
  static List<int> deserializeIntList(List<String>? value) =>
      value == null ? [] : value.map((e) => int.parse(e)).toList();

  /// DateTime
  static String serializeDateTime(DateTime value) => value.toIso8601String();
  static DateTime? deserializeDateTime(String? value) =>
      value == null ? null : DateTime.parse(value);

  /// trackingstatus
  static String serializeTrackingStatus(TrackingStatus value) {
    return value.name;
  }

  static TrackingStatus? deserializeTrackingStatus(String? value) {
    return value == null ? null : TrackingStatus.values.byName(value);
  }

  /// Duration
  static int serializeDuration(Duration value) => value.inSeconds;
  static Duration? deserializeDuration(int? value) =>
      value == null ? null : Duration(seconds: value);

  /// CalendarEventId
  static List<String> serializeCalendarEventId(List<CalendarEventId> value) =>
      value.map((e) => e.toString()).toList();
  static List<CalendarEventId> deserializeCalendarEventId(
          List<String>? value) =>
      value == null
          ? []
          : value.map((value) => CalendarEventId.toObject(value)).toList();

  /// gps List
  static List<String> serializeGpsList(List<GPS> value) =>
      value.map((e) => e.toString()).toList();
  static List<GPS> deserializeGpsList(List<String>? value) =>
      value == null ? [] : value.map((e) => GPS.toObject(e)).toList();

  /// DateTime value
  static List<String> serializeDateTimeList(List<DateTime> value) =>
      value.map((e) => e.toIso8601String()).toList();
  static List<DateTime>? deserializeDateTimeList(List<String>? value) =>
      value == null ? [] : value.map((e) => DateTime.parse(e)).toList();

  /// GPS
  static String serializeGps(GPS value) => value.toString();
  static GPS? deserializeGps(String? value) =>
      value == null ? null : GPS.toObject(value);

  /// OSMLookup
  static String serializeOsmLookup(OsmLookupConditions value) => value.name;
  static OsmLookupConditions? deserializeOsmLookup(String? value) =>
      value == null
          ? OsmLookupConditions.never
          : OsmLookupConditions.values.byName(value);

  /// Location Accuracy
  static String serializeLocationAccuracy(LocationAccuracy value) => value.name;
  static LocationAccuracy? deserializeLocationAccuracy(String? value) =>
      value == null
          ? LocationAccuracy.best
          : LocationAccuracy.values.byName(value);

  /// OSMWeekdays
  static String serializeWeekdays(Weekdays value) => value.name;
  static Weekdays? deserializeWeekdays(String? value) =>
      value == null ? Weekdays.mondayFirst : Weekdays.values.byName(value);

  /// DateFormat
  static String serializeDateFormat(DateFormat value) => value.name;
  static DateFormat? deserializeDateFormat(String? value) =>
      value == null ? DateFormat.yyyymmdd : DateFormat.values.byName(value);

  /// GpsPrecision
  static String serializeGpsPrecision(GpsPrecision value) => value.name;
  static GpsPrecision? deserializeGpsPrecision(String? value) =>
      value == null ? GpsPrecision.best : GpsPrecision.values.byName(value);

  /// List<SharedTrackpointAlias>
  static List<String> serializeSharedTrackpointAliasList(
          List<SharedTrackpointAlias> value) =>
      value
          .map(
            (e) => e.toString(),
          )
          .toList();
  static List<SharedTrackpointAlias> desrializeSharedrackpointAlias(
          List<String>? value) =>
      value == null
          ? []
          : value.map((e) => SharedTrackpointAlias.toObject(e)).toList();

  /// List<SharedTrackpointUser>
  static List<String> serializeSharedTrackpointUserList(
          List<SharedTrackpointUser> value) =>
      value
          .map(
            (e) => e.toString(),
          )
          .toList();
  static List<SharedTrackpointUser> desrializeSharedrackpointUser(
          List<String>? value) =>
      value == null
          ? []
          : value.map((e) => SharedTrackpointUser.toObject(e)).toList();

  /// List<SharedTrackpointTask>
  static List<String> serializeSharedTrackpointTaskList(
          List<SharedTrackpointTask> value) =>
      value
          .map(
            (e) => e.toString(),
          )
          .toList();
  static List<SharedTrackpointTask> desrializeSharedrackpointTask(
          List<String>? value) =>
      value == null
          ? []
          : value.map((e) => SharedTrackpointTask.toObject(e)).toList();

/* 

  // ModelTrackPoint
  static String serializeModelTrackPoint(ModelTrackPoint value) =>
      Model.toJson(value.toMap());
  static ModelTrackPoint? deserializeModelTrackPoint(String? value) =>
      value == null ? null : ModelTrackPoint.fromMap(Model.fromJson(value));

  /// List ModelAlias
  static List<String> serializeModelAliasList(List<ModelAlias> value) =>
      value.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelAlias>? deserializeModelAliasList(List<String>? value) =>
      value == null
          ? []
          : value.map((e) => ModelAlias.fromMap(Model.fromJson(e))).toList();

  /// List ModelUser
  static List<String> serializeModelUserList(List<ModelUser> value) =>
      value.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelUser>? deserializeModelUserList(List<String>? value) =>
      value == null
          ? []
          : value.map((e) => ModelUser.fromMap(Model.fromJson(e))).toList();

  /// List ModelTask
  static List<String> serializeModelTaskList(List<ModelTask> value) =>
      value.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelTask>? deserializeModelTaskList(List<String>? value) =>
      value == null
          ? []
          : value.map((e) => ModelTask.fromMap(Model.fromJson(e))).toList();

  /// List ModelTrackPoint
  static List<String> serializeModelTrackPointList(
          List<ModelTrackPoint> value) =>
      value.map((e) => Model.toJson(e.toMap())).toList();
  static List<ModelTrackPoint>? deserializeModelTrackPointList(
          List<String>? value) =>
      value == null
          ? []
          : value
              .map((e) => ModelTrackPoint.fromMap(Model.fromJson(e)))
              .toList();
 */
}
