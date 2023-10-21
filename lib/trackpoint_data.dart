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

import 'package:chaostours/calendar.dart';
import 'package:chaostours/data_bridge.dart';
import 'package:chaostours/model/model_trackpoint.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_alias_group.dart';
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/conf/app_settings.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/logger.dart';

class TrackPointData {
  static final Logger logger = Logger.logger<TrackPointData>();
  ModelTrackPoint? trackPoint;
  final bridge = DataBridge.instance;
  final GPS gps;
  final DateTime timeStart;
  DateTime get timeEnd => DateTime.now();
  final List<ModelAlias> aliasModels;
  final List<ModelAliasGroup> aliasGroupModels;
  final List<ModelUser> userModels;
  final List<ModelTask> taskModels;
  final List<CalendarEventId> calendarEventIds;
  final String addressText;

  GPS get gpslastStatusChange => bridge.trackPointGpslastStatusChange ?? gps;

  /// defaults to AppSettings.distanceTreshold
  int get radius {
    return aliasModels.isEmpty
        ? AppSettings.distanceTreshold
        : aliasModels.first.radius;
  }

  /// defaults to bridge.gpsPoints -> gps
  GPS get calcGps {
    return bridge.calcGpsPoints.isNotEmpty
        ? bridge.calcGpsPoints.first
        : (bridge.gpsPoints.isEmpty ? gps : bridge.gpsPoints.first);
  }

  /// distance from radius center
  int get distanceStanding => bridge.gpsPoints.isEmpty
      ? 0
      : GPS
          .distance(
              bridge.calcGpsPoints.isNotEmpty
                  ? bridge.calcGpsPoints.first
                  : bridge.gpsPoints.first,
              gps)
          .round();

  /// inversion of distanceStanding
  int get distanceStandingFromBorder => (radius - distanceStanding).round();

  /// distance over calcGpsPoints in meter
  int get distanceMoving {
    return GPS.distanceOverTrackList(bridge.calcGpsPoints).round();
  }

  List<int> get aliasIds => aliasModels.map((e) => e.id).toList();
  List<int> get taskIds => taskModels.map((e) => e.id).toList();
  List<int> get userIds => userModels.map((e) => e.id).toList();

  String get aliasText => aliasModels.isEmpty
      ? ' ---'
      : '--> ${aliasModels.map((e) {
            return e.title;
          }).toList().join('\n- ')}';

  String get tasksText => taskModels.isEmpty
      ? ' ---'
      : taskModels
          .map((e) {
            return '- ${e.title}';
          })
          .toList()
          .join('\n');
  String get usersText => userModels.isEmpty
      ? ' ---'
      : userModels
          .map((e) {
            return '- ${e.title}';
          })
          .toList()
          .join('\n');

  String get trackPointNotes => trackPoint?.notes ?? '';

  String get durationText => timeElapsed(timeStart, timeEnd, false);

  Duration get duration => timeDifference(timeStart, timeEnd);

  List<CalendarEventId> get calendarIds {
    var list = <CalendarEventId>[];
    for (var model in aliasGroupModels) {
      list.add(CalendarEventId(calendarId: model.idCalendar));
    }
    return list;
  }

  /// defaults to data from DataBridge
  static Future<TrackPointData> trackPointData(
      {ModelTrackPoint? trackPoint}) async {
    final bridge = DataBridge.instance;

    GPS? gps = bridge.calcGpsPoints.isEmpty ? null : bridge.calcGpsPoints.first;
    gps ??= bridge.gpsPoints.isEmpty ? null : bridge.gpsPoints.first;
    gps ??= await GPS.gps();

    DateTime tStart = trackPoint?.timeStart ??
        (bridge.trackPointGpslastStatusChange?.time ??
            (bridge.gpsPoints.isNotEmpty
                ? bridge.gpsPoints.last.time
                : DateTime.now()));

    List<int> aliasIds = trackPoint?.aliasIds ?? bridge.trackPointAliasIdList;
    List<ModelAlias> aliasModels = await ModelAlias.byIdList(aliasIds);

    List<int> taskIds = trackPoint?.taskIds ?? bridge.trackPointTaskIdList;
    List<ModelTask> taskModels = await ModelTask.byIdList(taskIds);

    List<int> userIds = trackPoint?.userIds ?? bridge.trackPointUserIdList;
    List<ModelUser> userModels = await ModelUser.byIdList(userIds);

    String addressText = trackPoint?.address ?? bridge.currentAddress;

    List<CalendarEventId> calendarEventIds =
        (trackPoint?.calendarEventIds ?? bridge.lastCalendarEventIds);

    List<ModelAliasGroup> aliasGroupModels =
        await ModelAliasGroup.byIdList(aliasModels
            .map(
              (e) => e.groupId,
            )
            .toList());

    return TrackPointData(
        gps: gps,
        timeStart: tStart,
        aliasModels: aliasModels,
        aliasGroupModels: aliasGroupModels,
        taskModels: taskModels,
        userModels: userModels,
        addressText: addressText,
        calendarEventIds: calendarEventIds);
  }

  TrackPointData(
      {required this.gps,
      required this.timeStart,
      required this.aliasModels,
      required this.aliasGroupModels,
      required this.userModels,
      required this.taskModels,
      required this.addressText,
      required this.calendarEventIds,
      this.trackPoint});
}
