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

import 'package:chaostours/model/model_trackpoint_alias.dart';
import 'package:chaostours/model/model_trackpoint_task.dart';
import 'package:chaostours/model/model_trackpoint_user.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

///
import 'package:chaostours/channel/trackpoint_data.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_task.dart';
import 'package:chaostours/shared/shared_trackpoint_user.dart';
import 'package:chaostours/channel/tracking.dart';
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
  statusDuration,
  lastAddress,
  lastFullAddress;
}

class DataChannel extends TrackPointData {
  static final Logger logger = Logger.logger<DataChannel>();
  static DataChannel? _instance;
  factory DataChannel() => _instance ??= DataChannel._();
  bool _initialized = false;
  bool get initalized => _initialized;
  int tick = 0;
  DateTime start = DateTime.now();

  /// computed values
  TrackingStatus trackingStatus = TrackingStatus.standing;

  TrackingStatus trackingStatusTrigger = TrackingStatus.none;

  int distanceMoving = 0;
  int distanceStanding = 0;

  int get distance => trackingStatus == TrackingStatus.standing
      ? distanceStanding
      : distanceMoving;

  bool skipTracking = false;

  Future<String> setTrackpointNotes(String text) async {
    return (notes = await Cache.backgroundTrackPointNotes.save<String>(text));
  }

  DataChannel._() {
    if (_instance == null) {
      Future.microtask(() async {
        await for (var data in FlutterBackgroundService()
            .on(BackgroundChannelCommand.onTracking.toString())) {
          _initialized = true;
          Cache.reload();
          try {
            tick = int.parse(data?[DataChannelKey.tick.toString()] ?? '0');

            /// serialized values
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
            final oldTrackingStatus = trackingStatus;
            trackingStatus = TypeAdapter.deserializeTrackingStatus(
                    data?[DataChannelKey.trackingStatus.toString()]) ??
                TrackingStatus.standing;

            /// conditioned string values
            final addr = data?[DataChannelKey.lastAddress.toString()] ?? '';
            if (addr.isNotEmpty) {
              address = addr;
            } else {
              final cachedAddr = await Cache.addressMostRecent.load<String>('');
              if (cachedAddr.isNotEmpty) {
                address =
                    'Most Recent: ${await Cache.addressMostRecent.load<String>('-')}';
              }
            }
            final fullAddr =
                data?[DataChannelKey.lastFullAddress.toString()] ?? '';
            if (fullAddr.isNotEmpty) {
              fullAddress = fullAddr;
            } else {
              final cachedFullAddr =
                  await Cache.addressMostRecent.load<String>('');
              if (cachedFullAddr.isNotEmpty) {
                fullAddress =
                    'Most Recent: ${await Cache.addressFullMostRecent.load<String>('-')}';
              }
            }

            /// Cached values
            trackingStatusTrigger = await Cache.trackingStatusTriggered
                .load<TrackingStatus>(TrackingStatus.none);
            notes = await Cache.backgroundTrackPointNotes.load<String>('');

            skipTracking = await Cache.backgroundTrackPointSkipRecordOnce
                .load<bool>(false);

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

            await updateAliasList();
            await updateUserList();
            await updateTaskList();

            /// fire events
            EventManager.fire<DataChannel>(_instance!);

            if (oldTrackingStatus != trackingStatus) {
              EventManager.fire<TrackingStatus>(trackingStatus);
            }

            logger.log('Datachannel finished');
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

  void sortUser() {
    userList.sort((modelA, modelB) {
      final a = modelA.model.sortOrder;
      final b = modelB.model.sortOrder;
      int result;
      if (a.isEmpty && b.isEmpty) {
        result = 0;
      } else if (a.isEmpty) {
        result = 1;
      } else if (b.isEmpty) {
        result = -1;
      } else {
        // Ascending Order
        result = a.compareTo(b);
      }
      return result;
    });
  }

  void sortTask() {
    taskList.sort((modelA, modelB) {
      final a = modelA.model.sortOrder;
      final b = modelB.model.sortOrder;
      int result;
      if (a.isEmpty && b.isEmpty) {
        result = 0;
      } else if (a.isEmpty) {
        result = 1;
      } else if (b.isEmpty) {
        result = -1;
      } else {
        // Ascending Order
        result = a.compareTo(b);
      }
      return result;
    });
  }

  Future<void> updateAssets() async {
    await updateAliasList();
    await updateUserList();
    await updateTaskList();
  }

  /// updated on each tracking interval from
  Future<void> updateAliasList() async {
    /// load ids from shared and database
    final sharedAliasList = await Cache.backgroundSharedAliasList
        .load<List<SharedTrackpointAlias>>([]);
    final modelAliasList = await ModelAlias.byIdList(sharedAliasList
        .map(
          (e) => e.id,
        )
        .toList());
    List<ModelTrackpointAlias> list = [];
    for (var shared in sharedAliasList) {
      ModelAlias model;
      try {
        model = modelAliasList.firstWhere((model) => model.id == shared.id);
      } catch (e) {
        continue;
      }
      try {
        list.add(ModelTrackpointAlias(
            model: model, trackpointId: 0, notes: shared.notes));
      } catch (e) {
        /// ignore and skip element
      }
    }
    aliasList = list;
  }

  Future<void> updateUserList() async {
    /// load ids from shared and database
    final sharedUserList = await Cache.backgroundSharedUserList
        .load<List<SharedTrackpointUser>>([]);
    final modelUserList = await ModelUser.byIdList(sharedUserList
        .map(
          (e) => e.id,
        )
        .toList());
    List<ModelTrackpointUser> list = [];
    for (var shared in sharedUserList) {
      try {
        list.add(ModelTrackpointUser(
            model: modelUserList.firstWhere((model) => model.id == shared.id),
            trackpointId: 0,
            notes: shared.notes));
      } catch (e) {
        /// ignore and skip element
      }
    }
    userList = list;
  }

  Future<void> updateTaskList() async {
    /// load ids from shared and database
    final sharedTaskList = await Cache.backgroundSharedTaskList
        .load<List<SharedTrackpointTask>>([]);
    final modelTaskList = await ModelTask.byIdList(sharedTaskList
        .map(
          (e) => e.id,
        )
        .toList());
    List<ModelTrackpointTask> list = [];
    for (var shared in sharedTaskList) {
      try {
        list.add(ModelTrackpointTask(
            model: modelTaskList.firstWhere((model) => model.id == shared.id),
            trackpointId: 0,
            notes: shared.notes));
      } catch (e) {
        /// ignore and skip element
      }
    }
    taskList = list;
  }
}
