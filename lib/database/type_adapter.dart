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
import 'package:chaostours/database/database.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/channel/tracking.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:geolocator/geolocator.dart';

class TypeAdapter {
  static final Logger logger = Logger.logger<TypeAdapter>();

  // wrapper to DB type adaper
  static int serializeBool(bool value) => value ? 1 : 0;
  static bool deserializeBool(Object? value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value > 0;
    }
    if (value is String) {
      try {
        return int.parse(value.toString()) > 0;
      } catch (e) {
        return fallback;
      }
    }
    return fallback;
  }

  static int timeToInt(DateTime time) {
    return (time.millisecondsSinceEpoch / 1000).round();
  }

  static DateTime intToTime(Object? i, {int fallback = 0}) {
    int t = parseInt(i, fallback: fallback);

    return t == 0
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(parseInt(t) * 1000);
  }

  static int parseInt(Object? value, {int fallback = 0}) {
    if (value == null) {
      return fallback;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      try {
        return int.parse(value.trim());
      } catch (e) {
        return fallback;
      }
    }
    return fallback;
  }

  static double parseDouble(Object? value, {double fallback = 0.0}) {
    if (value == null) {
      return fallback;
    }
    if (value is double) {
      return value;
    }
    if (value is String) {
      try {
        return double.parse(value.trim());
      } catch (e) {
        return fallback;
      }
    }
    return fallback;
  }

  static String parseString(Object? text, {fallback = ''}) {
    if (text == null) {
      return fallback;
    }
    if (text is String) {
      return text;
    }
    return text.toString();
  }

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
  static List<SharedTrackpointAlias> deserializeSharedrackpointAliasList(
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
  static List<SharedTrackpointUser> deserializeSharedrackpointUserList(
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
  static List<SharedTrackpointTask> deserializeSharedrackpointTaskList(
          List<String>? value) =>
      value == null
          ? []
          : value.map((e) => SharedTrackpointTask.toObject(e)).toList();

  /// FlexSchemeLookup
  static String serializeFlexScheme(FlexScheme value) => value.name;
  static FlexScheme? deserializeFlexScheme(String? value) {
    if (value == null) {
      return FlexScheme.material;
    }
    try {
      return FlexScheme.values.byName(value);
    } catch (e) {
      logger
          .warn('FlexScheme $value not found. Fallback to FlexScheme.material');
      return FlexScheme.material;
    }
  }
}
