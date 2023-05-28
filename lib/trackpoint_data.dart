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
import 'package:chaostours/model/model_task.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/conf/globals.dart';
import 'package:chaostours/util.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/view/app_widgets.dart';

class TrackPointData {
  static final Logger logger = Logger.logger<TrackPointData>();
  ModelTrackPoint? tp;
  late DateTime tStart;
  late DateTime tEnd;
  late PendingGps gpslastStatusChange;
  late int distanceStanding;
  late int distanceStandingFromBorder;
  late int standingRadius;
  late double distanceMoving;
  List<ModelAlias> aliasList = [];
  late String aliasText;
  List<ModelUser> userList = [];
  late String tasksText;
  List<ModelTask> taskList = [];
  late String usersText;
  late String trackPointNotes;
  late String durationText;
  late String addressText;
  late String notes;
  String calendarId = '';
  String calendarEventId = '';

  TrackPointData({this.tp}) {
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
        var alias = ModelAlias.getAlias(bridge.trackPointAliasIdList.first);
        gps = GPS(alias.lat, alias.lon);
        radius = alias.radius;
      } else {
        gps = bridge.trackPointGpsStartStanding!;
        radius = Globals.distanceTreshold;
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
      var aliasIds = tp?.idAlias ?? bridge.trackPointAliasIdList;
      aliasList = aliasIds.map((id) => ModelAlias.getAlias(id)).toList();
      // don't sort alias
      aliasText = aliasList.isEmpty
          ? ' ---'
          : '${aliasList.length == 1 ? '-' : '-->'} ${aliasList.map((e) {
                return e.alias;
              }).toList().join('\n- ')}';
    } catch (e, stk) {
      logger.error('process aliasIds: $e', stk);
      rethrow;
    }
    try {
      var taskIds = tp?.idTask ?? bridge.trackPointTaskIdList;
      taskList = taskIds.map((id) => ModelTask.getTask(id)).toList();
      taskList.sort((a, b) => a.sortOrder - b.sortOrder);
      tasksText = taskList.isEmpty
          ? ' ---'
          : taskList
              .map((e) {
                return '- ${e.task}';
              })
              .toList()
              .join('\n');
    } catch (e, stk) {
      logger.error('process taskIds: $e', stk);
      rethrow;
    }
    try {
      var userIds = tp?.idUser ?? bridge.trackPointUserIdList;
      userList = userIds.map((id) => ModelUser.getUser(id)).toList();
      userList.sort((a, b) => a.sortOrder - b.sortOrder);
      usersText = userList.isEmpty
          ? ' ---'
          : userList
              .map((e) {
                return '- ${e.user}';
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
      var calData = (tp?.calendarId ??
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
