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

import 'package:chaostours/channel/notification_channel.dart';
import 'package:chaostours/tracking.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

///
import 'package:chaostours/util.dart' as util;
import 'package:chaostours/channel/background_channel.dart';
import 'package:chaostours/conf/app_user_settings.dart';
import 'package:chaostours/database/cache.dart';
import 'package:chaostours/database/type_adapter.dart';
import 'package:chaostours/event_manager.dart';
import 'package:chaostours/gps.dart';
import 'package:chaostours/logger.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/model/model_user.dart';
import 'package:chaostours/model/model_task.dart';

typedef Callback = void Function();

enum DataChannelKey {
  tick,
  gps,
  gpsPoints,
  gpsSmoothPoints,
  gpsCalcPoints,
  gpsLastStatusChange,
  gpsLastStatusStanding,
  gpsLastStatusMoving,
  trackingStatus,
  lastAddress,
  lastFullAddress;
}

class DataChannel {
  static final Logger logger = Logger.logger<DataChannel>();
  static DataChannel? _instance;
  factory DataChannel() => _instance ??= DataChannel._();
  bool _initialized = false;
  bool get initalized => _initialized;
  int tick = 0;
  GPS? gps;
  List<GPS> gpsPoints = [];
  List<GPS> gpsSmoothPoints = [];
  List<GPS> gpsCalcPoints = [];
  GPS? gpsLastStatusChange;
  GPS? gpsLastStatusStanding;
  GPS? gpsLastStatusMoving;

  /// computed values
  TrackingStatus trackingStatus = TrackingStatus.standing;

  TrackingStatus statusTrigger = TrackingStatus.none;

  int distanceMoving = 0;
  int distanceStanding = 0;

  int get distance => trackingStatus == TrackingStatus.standing
      ? distanceStanding
      : distanceMoving;

  Duration get duration => gpsPoints.isEmpty
      ? Duration.zero
      : gpsPoints.first.time.difference(gpsPoints.last.time).abs();

  int distanceTreshold = 0; // meter
  Duration durationTreshold = Duration.zero;

  String address = '';
  String fullAddress = '';

  List<ModelAlias> _aliasList = [];
  List<ModelUser> _userList = [];
  List<ModelTask> _taskList = [];
  String _notes = '';
  List<ModelAlias> get aliasList => _aliasList;
  List<ModelUser> get userList => _userList;
  List<ModelTask> get taskList => _taskList;
  String get notes => _notes;

  setAliasList(List<ModelAlias> models, [Callback? callback]) {
    Cache.backgroundAliasIdList
        .save<List<int>>(models.map((e) => e.id).toList())
        .then(
      (value) {
        _aliasList = models;
      },
    );
    callback?.call();
  }

  setUserList(List<ModelUser> models, [Callback? callback]) {
    Cache.backgroundUserIdList
        .save<List<int>>(models.map((e) => e.id).toList())
        .then(
      (value) {
        _userList = models;
      },
    );
    callback?.call();
  }

  setTaskList(List<ModelTask> models, [Callback? callback]) {
    Cache.backgroundUserIdList
        .save<List<int>>(models.map((e) => e.id).toList())
        .then(
      (value) {
        _taskList = models;
      },
    );
    callback?.call();
  }

  set notes(String text) {
    Cache.backgroundTrackPointUserNotes.save<String>(notes).then(
      (value) {
        _notes = text;
      },
    );
  }

  DataChannel._() {
    if (_instance == null) {
      Future.microtask(() async {
        await for (var data in FlutterBackgroundService()
            .on(BackgroundChannelCommand.onTracking.toString())) {
          _initialized = true;
          tick++;
          try {
            /// stream values
            gps = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gps.toString()]);
            gpsPoints = TypeAdapter.deserializeGpsList(
                stringify(data?[DataChannelKey.gpsPoints.toString()] ?? []));
            gpsSmoothPoints = TypeAdapter.deserializeGpsList(stringify(
                data?[DataChannelKey.gpsSmoothPoints.toString()] ?? []));
            gpsCalcPoints = TypeAdapter.deserializeGpsList(stringify(
                data?[DataChannelKey.gpsCalcPoints.toString()] ?? []));
            gpsLastStatusChange = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gpsLastStatusChange.toString()]);
            gpsLastStatusStanding = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gpsLastStatusStanding.toString()]);
            gpsLastStatusMoving = TypeAdapter.deserializeGps(
                data?[DataChannelKey.gpsLastStatusMoving.toString()]);
            address = data?[DataChannelKey.lastAddress.toString()] ?? '-';
            fullAddress =
                data?[DataChannelKey.lastFullAddress.toString()] ?? '-';

            final TrackingStatus status = TypeAdapter.deserializeTrackingStatus(
                    data?[DataChannelKey.trackingStatus.toString()]) ??
                TrackingStatus.standing;

            /// compute values
            final bool statusChanged = status != trackingStatus;
            trackingStatus = status;

            distanceMoving = gpsPoints.isNotEmpty
                ? GPS.distanceOverTrackList(gpsPoints).round()
                : 0;
            distanceStanding = gpsLastStatusStanding != null &&
                    gpsPoints.isNotEmpty
                ? GPS.distance(gpsLastStatusStanding!, gpsPoints.first).round()
                : 0;
            Cache cache = Cache.appSettingDistanceTreshold;
            distanceTreshold = await cache
                .load<int>(AppUserSetting(cache).defaultValue as int);

            /// load from database
            _aliasList = gps == null
                ? []
                : await ModelAlias.byRadius(
                    gps: gps!, radius: distanceTreshold);

            List<int> ids;
            ids = await Cache.backgroundUserIdList.load<List<int>>([]);
            _userList = await ModelUser.byIdList(ids);

            ids = await Cache.backgroundTaskIdList.load<List<int>>([]);
            _taskList = await ModelTask.byIdList(ids);

            /// fire events
            EventManager.fire<DataChannel>(_instance!);

            if (statusChanged) {
              EventManager.fire<TrackingStatus>(trackingStatus);
            }

            /// notify user
            var notificationConfiguration = (statusChanged
                ? NotificationChannel.trackingStatusChangedConfiguration
                : NotificationChannel.ongoigTrackingUpdateConfiguration);

            NotificationChannel.sendTrackingUpdateNotification(
                title: 'Tick Update',
                message:
                    'T$tick ${statusChanged ? 'New Status' : 'Status'}: ${trackingStatus.name.toUpperCase()}'
                    ' since ${util.formatDuration(duration)}',
                details: notificationConfiguration);
          } catch (e, stk) {
            logger.error('Deserialize Channel Data: $e', stk);
          }
        }
      });
    }
  }

  List<String> stringify(List<dynamic> source) {
    List<String> cast = [];
    for (var dyn in source) {
      cast.add(dyn.toString());
    }
    return cast;
  }
}
