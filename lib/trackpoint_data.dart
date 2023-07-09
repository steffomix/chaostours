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
import 'package:chaostours/view/app_widgets.dart';

class TrackPointData {
  static final Logger logger = Logger.logger<TrackPointData>();
  ModelTrackPoint trackpoint = ModelTrackPoint.createTrackPoint();
  final bridge = DataBridge.instance;
  final GPS gps;
  final DateTime timeStart;
  DateTime get timeEnd => DateTime.now();
  final List<ModelAlias> currentAliasModels;
  final List<ModelAlias> aliasModels;
  final List<ModelUser> userModels;
  final List<ModelTask> taskModels;
  final String calendarEventId;
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
  List<int> get currentAliasIds => currentAliasModels.map((e) => e.id).toList();
  List<int> get taskIds => taskModels.map((e) => e.id).toList();
  List<int> get userIds => userModels.map((e) => e.id).toList();

  String get aliasText => aliasModels.isEmpty
      ? ' ---'
      : '--> ${aliasModels.map((e) {
            return e.title;
          }).toList().join('\n- ')}';
  String get currentAliasText => currentAliasModels.isEmpty
      ? ' ---'
      : '--> ${currentAliasModels.map((e) {
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

  String get trackPointNotes => trackpoint.notes;

  String get durationText => timeElapsed(timeStart, timeEnd, false);

  Duration get duration => timeDifference(timeStart, timeEnd);

  /// defaults to data from DataBridge
  static Future<TrackPointData> trackPointData(
      {ModelTrackPoint? trackpoint}) async {
    final bridge = DataBridge.instance;

    GPS? gps = bridge.calcGpsPoints.isEmpty ? null : bridge.calcGpsPoints.first;
    gps ??= bridge.gpsPoints.isEmpty ? null : bridge.gpsPoints.first;
    gps ??= await GPS.gps();

    DateTime tStart = trackpoint?.timeStart ??
        (bridge.trackPointGpslastStatusChange?.time ??
            (bridge.gpsPoints.isNotEmpty
                ? bridge.gpsPoints.last.time
                : DateTime.now()));

    List<int> aliasIds = trackpoint?.aliasIds ?? bridge.trackPointAliasIdList;
    List<ModelAlias> aliasModels = await ModelAlias.byIdList(aliasIds);

    List<int> currentAliasIds = bridge.currentAliasIdList;
    List<ModelAlias> currentAliasModels =
        await ModelAlias.byIdList(currentAliasIds);

    List<int> taskIds = trackpoint?.taskIds ?? bridge.trackPointTaskIdList;
    List<ModelTask> taskModels = await ModelTask.byIdList(taskIds);

    List<int> userIds = trackpoint?.userIds ?? bridge.trackPointUserIdList;
    List<ModelUser> userModels = await ModelUser.byIdList(userIds);

    String addressText = trackpoint?.address ?? bridge.currentAddress;

    String calendarEventId =
        (trackpoint?.calendarEventId ?? bridge.lastCalendarEventId);

    ModelAliasGroup? aliasGroupModel = await ModelAliasGroup.byId(
        aliasModels.isNotEmpty
            ? aliasModels.first.groupId
            : AppSettings.defaultAliasGroupId);

    var calendarId = aliasGroupModel?.idCalendar ?? '';

    return TrackPointData(
        gps: gps,
        timeStart: tStart,
        aliasModels: aliasModels,
        currentAliasModels: currentAliasModels,
        taskModels: taskModels,
        userModels: userModels,
        addressText: addressText,
        calendarEventId: calendarEventId);
  }

  TrackPointData(
      {required this.gps,
      required this.timeStart,
      required this.aliasModels,
      required this.currentAliasModels,
      required this.userModels,
      required this.taskModels,
      required this.addressText,
      required this.calendarEventId,
      ModelTrackPoint? trackPoint}) {
    if (trackPoint != null) {
      trackpoint = trackPoint;
    }
  }

  /// may fallback to use Cache if id doesn't exist
  static Future<TrackPointData> fromId(int id) async {
    var tp = await ModelTrackPoint.byId(id);
    await tp?.loadAssets();
    return TrackPointData(tp);
  }

  static Future<TrackPointData> fromTrackPoint(ModelTrackPoint tp) async {
    await tp.loadAssets();
    return TrackPointData(tp);
  }

  TrackPointData([this.tp]) {
    DataBridge bridge = DataBridge.instance;

    try {
      tStart = tp?.timeStart ??
          (bridge.trackPointGpslastStatusChange?.time ??
              bridge.gpsPoints.last.time);
      tEnd = tp?.timeEnd ?? DateTime.now();
    } catch (e, stk) {
      logger.error('process dates: $e', stk);
      rethrow;
    }
    try {
      gpslastStatusChange =
          bridge.trackPointGpslastStatusChange ?? bridge.gpsPoints.last;

      distanceMoving = bridge.gpsPoints.isEmpty
          ? 0.0
          : (GPS.distanceOverTrackList(bridge.gpsPoints) / 10).round() / 100;
    } catch (e, stk) {
      logger.error('calculate distance on status moving: $e', stk);
      rethrow;
    }
    try {
      GPS gps;
      int radius;
      if (bridge.trackPointAliasIdList.isNotEmpty) {
        var alias = ModelAlias.getModel(bridge.trackPointAliasIdList.first);
        gps = GPS(alias.lat, alias.lon);
        radius = alias.radius;
      } else {
        gps = bridge.trackPointGpsStartStanding!;
        radius = AppSettings.distanceTreshold;
      }
      distanceStanding = bridge.gpsPoints.isEmpty
          ? 0
          : GPS
              .distance(
                  bridge.calcGpsPoints.isNotEmpty
                      ? bridge.calcGpsPoints.first
                      : bridge.gpsPoints.first,
                  gps)
              .round();
      distanceStandingFromBorder = radius - distanceStanding;
      standingRadius = radius;
    } catch (e, stk) {
      logger.error(
          'unable to calculate distance on status standing, set distance to zero: $e',
          stk);
      distanceStanding = 0;
    }
    try {
      var aliasIds = tp?.aliasIds ?? bridge.trackPointAliasIdList;
      aliasList = aliasIds.map((id) => ModelAlias.getModel(id)).toList();
      // don't sort alias
      aliasText = aliasList.isEmpty
          ? ' ---'
          : '${aliasList.length == 1 ? '-' : '-->'} ${aliasList.map((e) {
                return e.title;
              }).toList().join('\n- ')}';
    } catch (e, stk) {
      logger.error('process aliasIds: $e', stk);
      rethrow;
    }
    try {
      var currentAliasIds = tp?.aliasIds ?? bridge.currentAliasIdList;
      currentAliasList =
          currentAliasIds.map((id) => ModelAlias.getModel(id)).toList();
      // don't sort alias
      currentAliasText = currentAliasList.isEmpty
          ? ' ---'
          : '${currentAliasList.length == 1 ? '-' : '-->'} ${currentAliasList.map((e) {
                return e.title;
              }).toList().join('\n- ')}';
    } catch (e, stk) {
      logger.error('process aliasIds: $e', stk);
      rethrow;
    }
    try {
      var taskIds = tp?.taskIds ?? bridge.trackPointTaskIdList;
      taskList = taskIds.map((id) => ModelTask.getModel(id)).toList();
      taskList.sort((a, b) => a.sortOrder - b.sortOrder);
      tasksText = taskList.isEmpty
          ? ' ---'
          : taskList
              .map((e) {
                return '- ${e.title}';
              })
              .toList()
              .join('\n');
    } catch (e, stk) {
      logger.error('process taskIds: $e', stk);
      rethrow;
    }
    try {
      var userIds = tp?.userIds ?? bridge.trackPointUserIdList;
      userList = userIds.map((id) => ModelUser.getModel(id)).toList();
      userList.sort((a, b) => a.sortOrder - b.sortOrder);
      usersText = userList.isEmpty
          ? ' ---'
          : userList
              .map((e) {
                return '- ${e.title}';
              })
              .toList()
              .join('\n');
    } catch (e, stk) {
      logger.error('process userIds: $e', stk);
      rethrow;
    }

    try {
      trackPointNotes = tp?.notes ?? bridge.trackPointUserNotes;
      durationText = timeElapsed(tStart, tEnd, false);
      var addr = tp?.address ?? bridge.currentAddress;
      addressText = addr.isEmpty ? '---' : addr;
    } catch (e, stk) {
      logger.error('process notes: $e', stk);
      rethrow;
    }
    try {
      /// calendar
      var calData = (tp?.calendarEventId ??
              '${bridge.selectedCalendarId};${bridge.lastCalendarEventId}')
          .split(';');
      if (calData.isNotEmpty) {
        calendarId = calData[0];
      }
      if (calData.length > 1) {
        calendarEventId = calData[1];
      }
    } catch (e, stk) {
      logger.error('process calendar: $e', stk);
      rethrow;
    }
  }
}
